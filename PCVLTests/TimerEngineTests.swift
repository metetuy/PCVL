import Foundation
import Testing
@testable import PCVL

struct TimerEngineTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    private func countdown(minutes: Int) -> TimerEngine {
        var engine = TimerEngine()
        engine.setTarget(seconds: minutes * 60)
        return engine
    }

    @Test func countsWallClockTimeEvenWhenTicksAreLate() {
        var engine = countdown(minutes: 25)
        engine.start(at: t0)
        // A throttled timer (App Nap, sleep) fires once, 10 minutes later.
        engine.tick(at: t0 + 600)
        #expect(engine.elapsedSeconds == 600)
        #expect(engine.formattedTime == "15:00")
        #expect(engine.state == .running)
    }

    @Test func completesExactlyAtTargetWhenTheTickOvershoots() {
        var engine = countdown(minutes: 1)
        engine.start(at: t0)
        engine.tick(at: t0 + 3600)
        #expect(engine.state == .completed)
        #expect(engine.elapsedSeconds == 60)
        #expect(engine.remainingSeconds == 0)
        #expect(engine.progress == 1)
    }

    @Test func pausedTimeIsNotCounted() {
        var engine = countdown(minutes: 25)
        engine.start(at: t0)
        engine.pause(at: t0 + 10.5)
        engine.tick(at: t0 + 100)
        #expect(engine.state == .paused)
        #expect(engine.elapsedSeconds == 10)

        engine.start(at: t0 + 200)
        engine.tick(at: t0 + 205)
        // 10.5s before the pause + 5s after resuming.
        #expect(engine.elapsedSeconds == 15)
    }

    @Test func stopwatchNeverCompletes() {
        var engine = TimerEngine()
        engine.setMode(.countUp)
        engine.start(at: t0)
        engine.tick(at: t0 + 10_000)
        #expect(engine.state == .running)
        #expect(engine.formattedTime == "166:40")
    }

    @Test func configurationIsLockedOutsideIdle() {
        var engine = countdown(minutes: 25)
        engine.start(at: t0)
        engine.setTarget(seconds: 60)
        engine.setMode(.countUp)
        #expect(engine.targetSeconds == 1500)
        #expect(engine.mode == .countDown)
    }

    @Test func targetHasAOneMinuteFloor() {
        var engine = TimerEngine()
        engine.setTarget(seconds: 5)
        #expect(engine.targetSeconds == 60)
    }

    @Test func completedTimerCannotBeRestartedWithoutReset() {
        var engine = countdown(minutes: 1)
        engine.start(at: t0)
        engine.tick(at: t0 + 60)
        engine.start(at: t0 + 61)
        #expect(engine.state == .completed)

        engine.reset()
        #expect(engine.state == .idle)
        #expect(engine.elapsedSeconds == 0)
        #expect(engine.formattedTime == "1:00")
    }
}
