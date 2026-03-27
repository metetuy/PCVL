import Foundation

// MARK: - Timer Mode

enum TimerMode: String, CaseIterable {
    case countDown = "Count Down"
    case countUp = "Count Up"
}

// MARK: - Timer State

enum TimerState {
    case idle
    case running
    case paused
    case completed
}

// MARK: - Timer Engine

struct TimerEngine {
    var mode: TimerMode = .countDown
    var state: TimerState = .idle
    var elapsedSeconds: Int = 0
    var targetSeconds: Int = 1500 // 25 minutes default

    // MARK: - Computed Properties

    /// Remaining seconds for countdown mode
    var remainingSeconds: Int {
        max(targetSeconds - elapsedSeconds, 0)
    }

    /// Progress from 0.0 to 1.0 for countdown ring animation
    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(targetSeconds), 1.0)
    }

    /// Formatted time string — shows remaining for countdown, elapsed for countup
    var formattedTime: String {
        let totalSeconds = mode == .countDown ? remainingSeconds : elapsedSeconds
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Short formatted time for menu bar display
    var shortFormattedTime: String {
        let totalSeconds = mode == .countDown ? remainingSeconds : elapsedSeconds
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Mutations

    mutating func tick() {
        guard state == .running else { return }
        elapsedSeconds += 1

        if mode == .countDown && elapsedSeconds >= targetSeconds {
            state = .completed
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
        elapsedSeconds = 0
    }

    mutating func setMode(_ newMode: TimerMode) {
        guard state == .idle else { return }
        mode = newMode
    }

    mutating func setTarget(seconds: Int) {
        guard state == .idle else { return }
        targetSeconds = max(60, seconds) // Minimum 1 minute
    }
}
