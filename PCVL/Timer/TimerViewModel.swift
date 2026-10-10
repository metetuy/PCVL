import Foundation
import Combine
import AppKit
import UserNotifications

@MainActor
class TimerViewModel: ObservableObject {
    @Published private(set) var engine = TimerEngine()
    @Published private(set) var isBreak: Bool = false

    enum AdjustableDuration {
        case work
        case breakTime

        var stepMinutes: Int {
            switch self {
            case .work: return 5
            case .breakTime: return 1
            }
        }

        var bounds: ClosedRange<Int> {
            switch self {
            case .work: return 5...480
            case .breakTime: return 1...30
            }
        }

        /// Quick picks offered in the status item's context menu, always including the
        /// default; the full range is reachable from the settings steppers.
        var menuPresets: [Int] {
            let presets: [Int]
            switch self {
            case .work: presets = [15, 20, 25, 30, 45, 50, 60, 90, 120]
            case .breakTime: presets = [1, 3, 5, 10, 15, 20, 30]
            }
            return presets.filter(bounds.contains)
        }

        var defaultMinutes: Int {
            switch self {
            case .work: return 25
            case .breakTime: return 5
            }
        }

        fileprivate var storageKey: String {
            switch self {
            case .work: return "workDuration"
            case .breakTime: return "breakDuration"
            }
        }
    }

    private var timer: Timer?
    private var sessionStartDate: Date?
    private var statisticsManager: StatisticsManager?
    private var taskManager: TaskManager?
    /// The task the session in progress counts toward, captured when it starts, so
    /// changing the current task never re-assigns time that already ran.
    private(set) var sessionTaskID: UUID?
    /// Wall clock, replaceable in tests.
    private let now: () -> Date
    var menuBarUpdater: ((String, Bool) -> Void)?

    // MARK: - Setup

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        engine.setTarget(seconds: workDuration)
        requestNotificationPermission()
    }

    func setStatisticsManager(_ manager: StatisticsManager) {
        self.statisticsManager = manager
    }

    func setTaskManager(_ manager: TaskManager) {
        self.taskManager = manager
    }

    // MARK: - Durations (persisted, in seconds)

    var workDuration: Int {
        get { storedSeconds(for: .work) }
        set { setDuration(.work, minutes: newValue / 60) }
    }

    var breakDuration: Int {
        get { storedSeconds(for: .breakTime) }
        set { setDuration(.breakTime, minutes: newValue / 60) }
    }

    func durationMinutes(for duration: AdjustableDuration) -> Int {
        storedSeconds(for: duration) / 60
    }

    func adjustDuration(_ duration: AdjustableDuration, byMinutes deltaMinutes: Int) {
        setDuration(duration, minutes: durationMinutes(for: duration) + deltaMinutes)
    }

    /// Durations only change while idle; the countdown picks up the phase's new length.
    func setDuration(_ duration: AdjustableDuration, minutes: Int) {
        guard isIdle else { return }
        let clamped = min(max(minutes, duration.bounds.lowerBound), duration.bounds.upperBound)
        objectWillChange.send()
        UserDefaults.standard.set(clamped * 60, forKey: duration.storageKey)
        if engine.mode == .countDown && duration == currentPhase {
            engine.setTarget(seconds: clamped * 60)
        }
    }

    private func storedSeconds(for duration: AdjustableDuration) -> Int {
        let minutes = UserDefaults.standard.integer(forKey: duration.storageKey) / 60
        guard minutes > 0 else { return duration.defaultMinutes * 60 }
        return min(max(minutes, duration.bounds.lowerBound), duration.bounds.upperBound) * 60
    }

    private var currentPhase: AdjustableDuration { isBreak ? .breakTime : .work }

    // MARK: - Computed State

    var isRunning: Bool { engine.state == .running }
    var isPaused: Bool { engine.state == .paused }
    var isIdle: Bool { engine.state == .idle }

    var mode: TimerMode {
        get { engine.mode }
        set {
            guard isIdle, newValue != engine.mode else { return }
            engine.setMode(newValue)
            if newValue == .countDown {
                engine.setTarget(seconds: storedSeconds(for: currentPhase))
            }
        }
    }

    var modeLabel: String {
        switch engine.mode {
        case .countDown: return isBreak ? "BREAK" : "FOCUS"
        case .countUp: return "STOPWATCH"
        }
    }

    /// The countdown duration that scrolling over the time adjusts, when idle.
    var editableCountdownDuration: AdjustableDuration? {
        guard isIdle, engine.mode == .countDown else { return nil }
        return currentPhase
    }

    /// A focus or stopwatch session is running or paused. The current task is locked
    /// meanwhile; breaks and finished phases leave it free for the next session.
    var isFocusSessionInProgress: Bool {
        Self.isFocusSessionInProgress(state: engine.state, isBreak: isBreak)
    }

    static func isFocusSessionInProgress(state: TimerState, isBreak: Bool) -> Bool {
        !isBreak && (state == .running || state == .paused)
    }

    /// Focus time of the session in progress, not yet recorded in the store.
    var inProgressFocusSeconds: Int {
        isFocusSessionInProgress ? engine.elapsedSeconds : 0
    }

    /// Duration of the phase that follows the current countdown, for the "up next" hint.
    var nextPhaseLabel: String? {
        guard engine.mode == .countDown else { return nil }
        return isBreak
            ? "Up next · Focus \(workDuration / 60) min"
            : "Up next · Break \(breakDuration / 60) min"
    }

    // MARK: - Actions

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

    func start() {
        let date = now()
        if isIdle {
            sessionStartDate = date
            sessionTaskID = isBreak ? nil : taskManager?.activeTaskID
        }
        engine.start(at: date)
        startTimer()
        updateMenuBarIcon()
    }

    func pause() {
        engine.pause(at: now())
        stopTimer()
        updateMenuBarIcon()
    }

    /// Ends the current session (recording it) and returns to an idle focus countdown.
    func reset() {
        endSession()
        isBreak = false
        if engine.mode == .countDown {
            engine.setTarget(seconds: workDuration)
        }
        updateMenuBarIcon()
    }

    var canSkipPhase: Bool { engine.mode == .countDown && !isIdle }

    /// Jumps to the other countdown phase: focus → break (starts right away),
    /// break → focus (waits for the user).
    func skipPhase() {
        endSession()
        isBreak.toggle()
        engine.setTarget(seconds: storedSeconds(for: currentPhase))
        if isBreak {
            start()
        } else {
            updateMenuBarIcon()
        }
    }

    // MARK: - Private

    /// Records whatever ran of the current session and stops the clock.
    private func endSession() {
        engine.tick(at: now())
        recordSessionIfNeeded()
        sessionStartDate = nil
        sessionTaskID = nil
        stopTimer()
        engine.reset()
    }

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        engine.tick(at: now())
        updateMenuBarIcon()
        if engine.state == .completed {
            handleCompletion()
        }
    }

    private func handleCompletion() {
        stopTimer()
        recordSessionIfNeeded()
        NSSound(named: .init("Funk"))?.play()
        sendCompletionNotification()
        updateMenuBarIcon()
    }

    private func recordSessionIfNeeded() {
        guard engine.elapsedSeconds > 0, let startDate = sessionStartDate else { return }
        let type: SessionType
        switch engine.mode {
        case .countDown: type = isBreak ? .shortBreak : .work
        case .countUp: type = .stopwatch
        }
        statisticsManager?.recordSession(
            duration: engine.elapsedSeconds,
            date: startDate,
            type: type,
            taskID: sessionTaskID
        )
        sessionStartDate = nil
        sessionTaskID = nil
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
        menuBarUpdater?(engine.formattedTime, isRunning)
    }
}
