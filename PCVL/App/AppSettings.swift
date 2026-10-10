import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - App Settings

/// Single owner of the app-wide preferences and actions shared by the panel's settings
/// tab, the window's settings screen and the status item's context menu. Every surface
/// binds to this object, so they cannot drift apart. Timer durations live on
/// `TimerViewModel` (they reconfigure the running engine), theme and font on
/// `ThemeManager`.
@MainActor
final class AppSettings: ObservableObject {
    @Published var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop) }
    }

    @Published var showTimerInMenuBar: Bool {
        didSet { defaults.set(showTimerInMenuBar, forKey: Keys.showTimerInMenuBar) }
    }

    /// Unit focus time is shown in, shared by the panel stats and the analytics window.
    @Published var statsTimeUnit: StatsTimeUnit {
        didSet { defaults.set(statsTimeUnit.rawValue, forKey: Keys.statsTimeUnit) }
    }

    private enum Keys {
        static let alwaysOnTop = "alwaysOnTop"
        static let showTimerInMenuBar = "showTimerInMenuBar"
        static let statsTimeUnit = "statsTimeUnit"
    }

    private let defaults: UserDefaults
    private let statsManager: StatisticsManager

    init(statsManager: StatisticsManager, defaults: UserDefaults = .standard) {
        self.statsManager = statsManager
        self.defaults = defaults
        alwaysOnTop = defaults.bool(forKey: Keys.alwaysOnTop)
        showTimerInMenuBar = defaults.bool(forKey: Keys.showTimerInMenuBar)
        statsTimeUnit = defaults.string(forKey: Keys.statsTimeUnit).flatMap(StatsTimeUnit.init(rawValue:)) ?? .minutes
    }

    // MARK: - Reset Statistics

    static let resetTitle = "Reset Statistics"
    static let resetMessage = "Are you sure you want to delete all session records? This action cannot be undone."

    /// Deletes every session record. SwiftUI surfaces confirm first via `resetStatisticsAlert`.
    func resetStatistics() {
        statsManager.deleteAllSessions()
    }

    /// Asks for confirmation in a standalone alert (for AppKit entry points like the context menu).
    func confirmResetStatistics() {
        let alert = NSAlert()
        alert.messageText = Self.resetTitle
        alert.informativeText = Self.resetMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            resetStatistics()
        }
    }

    // MARK: - Export

    /// Saves every recorded session to a user-chosen JSON file.
    func exportSessions() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "sessions_export.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try statsManager.exportedSessionsJSON().write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Quit

    func quit() {
        NSApp.terminate(nil)
    }
}
