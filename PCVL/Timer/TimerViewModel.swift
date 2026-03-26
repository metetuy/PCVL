import Foundation
import Combine
import AppKit

enum PomodoroPhase: String {
    case work = "Work"
    case shortBreak = "Break"
}

@MainActor
class TimerViewModel: ObservableObject {
    @Published var engine = TimerEngine()
    @Published var phase: PomodoroPhase = .work
    @Published var sessionsCompleted: Int = 0

    var workMinutes: Int = 25
    var breakMinutes: Int = 5

    private var timer: Timer?
    private var statisticsManager: StatisticsManager?
    private var sessionStartDate: Date?

    var isRunning: Bool { engine.state == .running }
    var isPaused: Bool { engine.state == .paused }
    var isIdle: Bool { engine.state == .idle }

    func setStatisticsManager(_ manager: StatisticsManager) {
        self.statisticsManager = manager
    }

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
        engine.reset()
        stopTimer()
        sessionStartDate = nil
        updateMenuBarIcon()
    }

    func toggleMode() {
        reset()
        if engine.mode == .countdown {
            engine.mode = .stopwatch
        } else {
            engine.mode = .countdown
            engine.setDuration(minutes: phase == .work ? workMinutes : breakMinutes)
        }
    }

    func skipPhase() {
        completePhase()
    }

    func updateWorkDuration(_ minutes: Int) {
        workMinutes = minutes
        if phase == .work && isIdle {
            engine.setDuration(minutes: minutes)
        }
    }

    func updateBreakDuration(_ minutes: Int) {
        breakMinutes = minutes
        if phase == .shortBreak && isIdle {
            engine.setDuration(minutes: minutes)
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        engine.tick()

        if engine.mode == .countdown && engine.isFinished {
            completePhase()
        }
    }

    private func completePhase() {
        stopTimer()

        if phase == .work {
            sessionsCompleted += 1
            if let startDate = sessionStartDate {
                let duration = Int(Date().timeIntervalSince(startDate))
                statisticsManager?.recordSession(
                    duration: duration,
                    date: startDate,
                    type: .work
                )
            }
        }

        sendNotification()

        // Switch phase
        if phase == .work {
            phase = .shortBreak
            engine.reset()
            engine.setDuration(minutes: breakMinutes)
        } else {
            phase = .work
            engine.reset()
            engine.setDuration(minutes: workMinutes)
        }

        sessionStartDate = nil
        updateMenuBarIcon()
    }

    private func sendNotification() {
        let notification = NSUserNotification()
        notification.title = "PCVL"
        notification.informativeText = phase == .work
            ? "Work session complete! Time for a break."
            : "Break is over! Ready to focus?"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func updateMenuBarIcon() {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        delegate.updateMenuBarIcon(isRunning: isRunning)
    }
}
