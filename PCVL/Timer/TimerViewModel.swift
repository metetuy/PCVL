import Foundation
import Combine
import AppKit
import UserNotifications

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var isBreak: Bool = false
    @Published private(set) var todayStats = TodayStats()

    /// Today's recorded focus totals, cached so the fullscreen timer can show them
    /// without querying the store on every tick.
    struct TodayStats {
        var focusSeconds = 0
        var sessions = 0
        var streak = 0
    }

    private var timer: Timer?
    private var sessionStartDate: Date?
    private var statisticsManager: StatisticsManager?
    private var statsObserver: AnyCancellable?
    var menuBarUpdater: ((String, Bool) -> Void)?

    enum AdjustableDuration {
        case work
        case breakTime

        var stepMinutes: Int {
            switch self {
            case .work:
                return 5
            case .breakTime:
                return 1
            }
        }

        var bounds: ClosedRange<Int> {
            switch self {
            case .work:
                return 5...480
            case .breakTime:
                return 1...30
            }
        }
    }

    // Persisted durations (in seconds)
    var workDuration: Int {
        get { UserDefaults.standard.integer(forKey: "workDuration").clamped(to: AdjustableDuration.work.bounds.inSeconds, default: 1500) }
        set {
            guard engine.state == .idle else { return }
            UserDefaults.standard.set(newValue, forKey: "workDuration")
            if engine.state == .idle && engine.mode == .countDown && !isBreak {
                engine.setTarget(seconds: newValue)
            }
            objectWillChange.send()
        }
    }

    var breakDuration: Int {
        get { UserDefaults.standard.integer(forKey: "breakDuration").clamped(to: AdjustableDuration.breakTime.bounds.inSeconds, default: 300) }
        set {
            guard engine.state == .idle else { return }
            UserDefaults.standard.set(newValue, forKey: "breakDuration")
            if engine.state == .idle && engine.mode == .countDown && isBreak {
                engine.setTarget(seconds: newValue)
            }
            objectWillChange.send()
        }
    }

    // MARK: - Computed State

    var isRunning: Bool { engine.state == .running }
    var isPaused: Bool { engine.state == .paused }
    var isIdle: Bool { engine.state == .idle }
    var isCompleted: Bool { engine.state == .completed }

    var mode: TimerMode {
        get { engine.mode }
        set {
            guard engine.state == .idle else { return }
            engine.setMode(newValue)
            if newValue == .countDown {
                engine.setTarget(seconds: isBreak ? breakDuration : workDuration)
            }
            objectWillChange.send()
        }
    }

    var modeLabel: String {
        switch engine.mode {
        case .countDown:
            return isBreak ? "BREAK" : "FOCUS"
        case .countUp:
            return "STOPWATCH"
        }
    }

    var editableCountdownDuration: AdjustableDuration? {
        guard engine.state == .idle, engine.mode == .countDown else { return nil }
        return isBreak ? .breakTime : .work
    }

    // MARK: - Setup

    init() {
        engine.setTarget(seconds: workDuration)
        requestNotificationPermission()
    }

    func setStatisticsManager(_ manager: StatisticsManager) {
        self.statisticsManager = manager
        statsObserver = manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTodayStats() }
        refreshTodayStats()
    }

    func refreshTodayStats() {
        guard let statisticsManager else { return }
        let today = statisticsManager.todayFocusSummary()
        todayStats = TodayStats(
            focusSeconds: today.seconds,
            sessions: today.sessions,
            streak: statisticsManager.currentStreak()
        )
    }

    /// Today's focus time including the session currently in progress.
    var liveTodayFocusSeconds: Int {
        let inProgress = !isBreak && (isRunning || isPaused) ? engine.elapsedSeconds : 0
        return todayStats.focusSeconds + inProgress
    }

    var liveTodayFocusText: String {
        let seconds = liveTodayFocusSeconds
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// One-line summary for the focus screen footer.
    var todaySummaryText: String {
        let sessions = todayStats.sessions
        return "Today \(liveTodayFocusText) · \(sessions) session\(sessions == 1 ? "" : "s") · \(todayStats.streak)-day streak"
    }

    /// Duration of the phase that follows the current countdown, for the "up next" hint.
    var nextPhaseLabel: String? {
        guard engine.mode == .countDown else { return nil }
        return isBreak
            ? "Up next · Focus \(workDuration / 60) min"
            : "Up next · Break \(breakDuration / 60) min"
    }

    // MARK: - Actions

    func start() {
        if engine.state == .idle {
            sessionStartDate = Date()
        }
        engine.start()
        startTimer()
        updateMenuBarIcon()
    }

    func pause() {
        engine.pause()
        stopTimer()
        updateMenuBarIcon()
    }

    func reset() {
        recordSessionIfNeeded()
        engine.reset()
        isBreak = false
        if engine.mode == .countDown {
            engine.setTarget(seconds: workDuration)
        }
        stopTimer()
        sessionStartDate = nil
        updateMenuBarIcon()
    }

    func skipToBreak() {
        recordSessionIfNeeded()
        engine.reset()
        isBreak = true
        engine.setTarget(seconds: breakDuration)
        sessionStartDate = Date()
        engine.start()
        startTimer()
    }

    func skipToWork() {
        engine.reset()
        isBreak = false
        engine.setTarget(seconds: workDuration)
        sessionStartDate = nil
        updateMenuBarIcon()
    }

    /// Label for the main button: Start / Pause / Resume, or Skip once a phase completed.
    var primaryActionLabel: String {
        switch engine.state {
        case .completed: return "Skip"
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle: return "Start"
        }
    }

    /// The main button's action, shared by every timer screen.
    func performPrimaryAction() {
        switch engine.state {
        case .completed: skipPhase()
        case .running: pause()
        case .paused, .idle: start()
        }
    }

    var canSkipPhase: Bool { engine.mode == .countDown && !isIdle }

    /// Jumps to the other countdown phase: focus → break, break → focus.
    func skipPhase() {
        if isBreak {
            skipToWork()
        } else {
            skipToBreak()
        }
    }

    // MARK: - Private

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.engine.tick()

                self.updateMenuBarIcon()

                if self.engine.state == .completed {
                    self.handleCompletion()
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleCompletion() {
        stopTimer()
        recordSessionIfNeeded()
        playCompletionSound()
        sendCompletionNotification()
        updateMenuBarIcon()
    }

    private func recordSessionIfNeeded() {
        guard engine.elapsedSeconds > 0, let startDate = sessionStartDate else { return }
        let duration = engine.elapsedSeconds
        let type: SessionType
        switch engine.mode {
        case .countDown:
            type = isBreak ? .shortBreak : .work
        case .countUp:
            type = .stopwatch
        }
        statisticsManager?.recordSession(duration: duration, date: startDate, type: type)
        sessionStartDate = nil
    }

    private func playCompletionSound() {
        NSSound(named: .init("Funk"))?.play()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        if isBreak {
            content.title = "Break Over"
            content.body = "Time to focus again!"
        } else {
            content.title = "Session Complete"
            content.body = "Great work! Take a break."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func updateMenuBarIcon() {
        menuBarUpdater?(engine.shortFormattedTime, isRunning)
    }

    func durationMinutes(for duration: AdjustableDuration) -> Int {
        switch duration {
        case .work:
            return workDuration / 60
        case .breakTime:
            return breakDuration / 60
        }
    }

    func adjustDuration(_ duration: AdjustableDuration, byMinutes deltaMinutes: Int) {
        let updatedMinutes = clamp(durationMinutes(for: duration) + deltaMinutes, for: duration)
        setDuration(duration, minutes: updatedMinutes)
    }

    func setDuration(_ duration: AdjustableDuration, minutes: Int) {
        let clampedMinutes = clamp(minutes, for: duration)

        switch duration {
        case .work:
            workDuration = clampedMinutes * 60
        case .breakTime:
            breakDuration = clampedMinutes * 60
        }
    }

    private func clamp(_ minutes: Int, for duration: AdjustableDuration) -> Int {
        Swift.min(Swift.max(minutes, duration.bounds.lowerBound), duration.bounds.upperBound)
    }
}

// MARK: - Int Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension ClosedRange where Bound == Int {
    var inSeconds: ClosedRange<Int> {
        (lowerBound * 60)...(upperBound * 60)
    }
}
