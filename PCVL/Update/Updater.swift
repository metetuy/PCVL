import AppKit
import Combine
import UserNotifications

// MARK: - Updater

/// Checks GitHub Releases for a newer version and installs it. The settings screens
/// show its status inline, the context menu reports through alerts. Automatic checks
/// run at most once a day and stay silent unless they find an update.
@MainActor
final class Updater: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(UpdateRelease)
        case downloading(UpdateRelease, progress: Double)
        case installing(UpdateRelease)
        case failed(String)
    }

    /// What the settings' update button does in the current status; nil while busy.
    enum Action {
        case check
        case install
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastChecked: Date?

    @Published var checksAutomatically: Bool {
        didSet {
            defaults.set(checksAutomatically, forKey: Keys.checksAutomatically)
            checkAutomaticallyIfDue()
        }
    }

    let currentVersion: AppVersion

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/metetuy/PCVL/releases/latest")!
    static let checkInterval: TimeInterval = 24 * 60 * 60

    private enum Keys {
        static let checksAutomatically = "checksForUpdatesAutomatically"
        static let lastChecked = "lastUpdateCheck"
        static let notifiedVersion = "notifiedUpdateVersion"
    }

    private let defaults: UserDefaults
    private weak var timer: TimerViewModel?
    private var scheduleTimer: Timer?

    init(defaults: UserDefaults = .standard, currentVersion: AppVersion = .current) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        checksAutomatically = defaults.object(forKey: Keys.checksAutomatically) as? Bool ?? true
        lastChecked = defaults.object(forKey: Keys.lastChecked) as? Date
    }

    /// The timer whose session in progress is recorded before restarting into an update.
    func setTimer(_ timer: TimerViewModel) {
        self.timer = timer
    }

    /// Starts the automatic checks: shortly after launch, then hourly whether a day
    /// has passed since the last check.
    func startAutomaticChecks() {
        scheduleTimer?.invalidate()
        // Scheduled on the main run loop, so it fires on the main actor.
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAutomaticallyIfDue() }
        }
        scheduleTimer?.tolerance = 10 * 60
        Task {
            try? await Task.sleep(for: .seconds(5))
            checkAutomaticallyIfDue()
        }
    }

    // MARK: - Display

    var availableRelease: UpdateRelease? {
        if case .available(let release) = status { return release }
        return nil
    }

    var isBusy: Bool {
        switch status {
        case .checking, .downloading, .installing: return true
        case .idle, .upToDate, .available, .failed: return false
        }
    }

    var action: Action? {
        switch status {
        case .idle, .upToDate, .failed: return .check
        case .available: return .install
        case .checking, .downloading, .installing: return nil
        }
    }

    var statusText: String {
        switch status {
        case .idle:
            guard let lastChecked else { return "Updates come from GitHub Releases" }
            return "Last checked \(lastChecked.formatted(.relative(presentation: .named)))"
        case .checking:
            return "Checking for updates…"
        case .upToDate:
            return "You're up to date"
        case .available(let release):
            return "Version \(release.version) is available"
        case .downloading(let release, let progress):
            return "Downloading \(release.version)… \(Int(progress * 100))%"
        case .installing(let release):
            return "Installing \(release.version)…"
        case .failed(let message):
            return message
        }
    }

    func performAction() {
        switch action {
        case .check: checkForUpdates()
        case .install: installUpdate()
        case nil: break
        }
    }

    // MARK: - Checking

    /// Checks now and shows the result in `status` (the settings screens).
    func checkForUpdates() {
        guard !isBusy else { return }
        Task { await check(silently: false) }
    }

    /// Checks now and reports the result in an alert (the context menu).
    func checkForUpdatesWithAlert() {
        guard !isBusy else { return }
        Task {
            await check(silently: false)
            presentStatusAlert()
        }
    }

    private func checkAutomaticallyIfDue() {
        guard checksAutomatically, !isBusy, availableRelease == nil else { return }
        if let lastChecked, Date().timeIntervalSince(lastChecked) < Self.checkInterval { return }
        Task { await check(silently: true) }
    }

    /// A silent check leaves no error behind and announces a found update once.
    private func check(silently: Bool) async {
        let previous = status
        status = .checking
        do {
            let release = try await fetchLatestUpdate()
            lastChecked = Date()
            defaults.set(lastChecked, forKey: Keys.lastChecked)
            if let release {
                status = .available(release)
                if silently { notifyOnce(about: release) }
            } else {
                status = .upToDate
            }
        } catch {
            status = silently ? previous : .failed(error.localizedDescription)
        }
    }

    private func fetchLatestUpdate() async throws -> UpdateRelease? {
        var request = URLRequest(url: Self.latestReleaseURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch response.statusCode {
        case 200: break
        case 404: return nil // Nothing published yet.
        default: throw UpdateError.requestFailed(statusCode: response.statusCode)
        }
        return try JSONDecoder().decode(GitHubRelease.self, from: data).update(over: currentVersion)
    }

    private func notifyOnce(about release: UpdateRelease) {
        guard defaults.string(forKey: Keys.notifiedVersion) != release.version.description else { return }
        defaults.set(release.version.description, forKey: Keys.notifiedVersion)

        let content = UNMutableNotificationContent()
        content.title = "PCVL \(release.version) is available"
        content.body = "Install it from Settings or the menu bar icon's right-click menu."
        let request = UNNotificationRequest(identifier: "update-\(release.version)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Installing

    /// Downloads, verifies and installs the available update, then relaunches. A
    /// session in progress is confirmed first and recorded before quitting.
    func installUpdate() {
        guard let release = availableRelease, confirmEndingSession() else { return }
        status = .downloading(release, progress: 0)
        let appURL = Bundle.main.bundleURL

        Task {
            do {
                try await UpdateInstaller.install(release, replacing: appURL) { fraction in
                    Task { @MainActor in self.setDownloadProgress(fraction) }
                }
                status = .installing(release)
                if let timer, !timer.isIdle { timer.reset() }
                try UpdateInstaller.relaunch(appURL)
                NSApp.terminate(nil)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func setDownloadProgress(_ fraction: Double) {
        guard case .downloading(let release, let progress) = status, fraction > progress else { return }
        status = .downloading(release, progress: fraction)
    }

    private func confirmEndingSession() -> Bool {
        guard let timer, !timer.isIdle else { return true }
        let alert = NSAlert()
        alert.messageText = "Restart to Update?"
        alert.informativeText = "PCVL restarts to finish the update. The current session ends and the time so far is recorded."
        alert.addButton(withTitle: "Update and Restart")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Alerts

    private func presentStatusAlert() {
        let alert = NSAlert()
        switch status {
        case .available(let release):
            alert.messageText = "PCVL \(release.version) is available"
            let notes = release.notes.count > 600 ? release.notes.prefix(600) + "…" : release.notes
            alert.informativeText = "You have version \(currentVersion).\(notes.isEmpty ? "" : "\n\n\(notes)")"
            alert.addButton(withTitle: "Install and Restart")
            alert.addButton(withTitle: "Later")
            alert.addButton(withTitle: "Release Notes")
        case .upToDate:
            alert.messageText = "You're up to date"
            alert.informativeText = "PCVL \(currentVersion) is the latest version."
        case .failed(let message):
            alert.messageText = "Couldn't check for updates"
            alert.informativeText = message
            alert.alertStyle = .warning
        default:
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard let release = availableRelease else { return }
        switch response {
        case .alertFirstButtonReturn: installUpdate()
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.pageURL)
        default: break
        }
    }
}
