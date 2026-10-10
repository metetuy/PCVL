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

/// Pure timer state machine. Elapsed time is measured against the wall clock the
/// caller passes in, so a late or throttled tick (App Nap, sleep) never loses time;
/// ticks only refresh `elapsedSeconds`.
struct TimerEngine {
    private(set) var mode: TimerMode = .countDown
    private(set) var state: TimerState = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var targetSeconds: Int = 1500 // 25 minutes default

    /// Running time banked before the last pause.
    private var accumulated: TimeInterval = 0
    /// Start of the current running stretch; nil unless running.
    private var runningSince: Date?

    // MARK: - Computed Properties

    /// Remaining seconds for countdown mode
    var remainingSeconds: Int {
        max(targetSeconds - elapsedSeconds, 0)
    }

    /// Progress from 0.0 to 1.0 for the countdown progress line
    var progress: Double {
        guard targetSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(targetSeconds), 1.0)
    }

    /// Shows remaining time for countdown, elapsed time for count up, e.g. "24:59".
    var formattedTime: String {
        let totalSeconds = mode == .countDown ? remainingSeconds : elapsedSeconds
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    // MARK: - Mutations

    /// Brings `elapsedSeconds` up to `now`; completes a countdown that reached its target.
    mutating func tick(at now: Date) {
        guard state == .running, let runningSince else { return }
        let elapsed = accumulated + max(now.timeIntervalSince(runningSince), 0)
        elapsedSeconds = Int(elapsed)

        if mode == .countDown && elapsedSeconds >= targetSeconds {
            elapsedSeconds = targetSeconds
            accumulated = TimeInterval(targetSeconds)
            self.runningSince = nil
            state = .completed
        }
    }

    mutating func start(at now: Date) {
        guard state == .idle || state == .paused else { return }
        runningSince = now
        state = .running
    }

    mutating func pause(at now: Date) {
        guard state == .running, let runningSince else { return }
        tick(at: now)
        guard state == .running else { return }
        accumulated += max(now.timeIntervalSince(runningSince), 0)
        self.runningSince = nil
        state = .paused
    }

    mutating func reset() {
        state = .idle
        elapsedSeconds = 0
        accumulated = 0
        runningSince = nil
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
