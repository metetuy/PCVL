import Foundation

enum TimerMode {
    case countdown
    case stopwatch
}

enum TimerState {
    case idle
    case running
    case paused
}

struct TimerEngine {
    var mode: TimerMode = .countdown
    var state: TimerState = .idle

    // Countdown
    var totalSeconds: Int = 25 * 60
    var remainingSeconds: Int = 25 * 60

    // Stopwatch
    var elapsedSeconds: Int = 0

    var displaySeconds: Int {
        switch mode {
        case .countdown: return remainingSeconds
        case .stopwatch: return elapsedSeconds
        }
    }

    var formattedTime: String {
        let seconds = displaySeconds
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var progress: Double {
        guard mode == .countdown, totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var isFinished: Bool {
        mode == .countdown && remainingSeconds <= 0
    }

    mutating func tick() {
        guard state == .running else { return }
        switch mode {
        case .countdown:
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
        case .stopwatch:
            elapsedSeconds += 1
        }
    }

    mutating func start() {
        state = .running
    }

    mutating func pause() {
        state = .paused
    }

    mutating func reset() {
        state = .idle
        remainingSeconds = totalSeconds
        elapsedSeconds = 0
    }

    mutating func setDuration(minutes: Int) {
        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
    }
}
