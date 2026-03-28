import Foundation
import Combine
import AppKit
import UserNotifications

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var isBreak: Bool = false
    

    private var timer: Timer?
    private var sessionStartDate: Date?
    private var statisticsManager: StatisticsManager?
    var menuBarUpdater: ((String, Bool) -> Void)?

    // Persisted durations (in seconds)
    var workDuration: Int {
        get { UserDefaults.standard.integer(forKey: "workDuration").clamped(to: 300...28800, default: 1500) }
        set {
            UserDefaults.standard.set(newValue, forKey: "workDuration")
            if engine.state == .idle && engine.mode == .countDown && !isBreak {
                engine.setTarget(seconds: newValue)
            }
            objectWillChange.send()
        }
    }

    var breakDuration: Int {
        get { UserDefaults.standard.integer(forKey: "breakDuration").clamped(to: 60...1800, default: 300) }
        set {
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

    // MARK: - Setup

    init() {
        engine.setTarget(seconds: workDuration)
        requestNotificationPermission()
    }

    func setStatisticsManager(_ manager: StatisticsManager) {
        self.statisticsManager = manager
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
}

// MARK: - Int Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>, default defaultValue: Int) -> Int {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
