import Foundation
import Testing
@testable import PCVL

/// Session recording with a controllable clock and an in-memory store.
@MainActor
struct TimerViewModelTests {
    private final class Clock {
        var now = Date()
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    private let clock = Clock()
    private let stats = StatisticsManager(inMemory: true)
    private let viewModel: TimerViewModel

    init() {
        let clock = self.clock
        viewModel = TimerViewModel(now: { clock.now })
        viewModel.setStatisticsManager(stats)
    }

    private var recorded: [SessionRecord] {
        stats.sessions(from: .distantPast, to: .distantFuture)
    }

    @Test func resetRecordsTheTimeThatActuallyRan() throws {
        viewModel.start()
        clock.advance(95) // no ticks in between
        viewModel.reset()

        let session = try #require(recorded.first)
        #expect(recorded.count == 1)
        #expect(session.duration == 95)
        #expect(session.sessionType == .work)
        #expect(viewModel.isIdle)
    }

    @Test func skippingRecordsFocusAndBreakSessions() {
        viewModel.start()
        clock.advance(120)
        viewModel.skipPhase()
        #expect(viewModel.isBreak)
        #expect(viewModel.isRunning, "the break starts right away")

        clock.advance(30)
        viewModel.skipPhase()
        #expect(!viewModel.isBreak)
        #expect(viewModel.isIdle, "focus waits for the user")

        let types = recorded.map(\.sessionType)
        #expect(types.sorted { $0.rawValue < $1.rawValue } == [.shortBreak, .work])
        #expect(recorded.map(\.duration).sorted() == [30, 120])
    }

    @Test func pausedTimeIsNotRecorded() throws {
        viewModel.start()
        clock.advance(60)
        viewModel.pause()
        clock.advance(600)
        viewModel.start()
        clock.advance(40)
        viewModel.reset()

        #expect(try #require(recorded.first).duration == 100)
    }

    @Test func idleResetRecordsNothing() {
        viewModel.reset()
        viewModel.skipPhase()
        viewModel.skipPhase()
        #expect(recorded.isEmpty)
    }

    @Test func stopwatchSessionsAreRecordedAsStopwatch() throws {
        viewModel.mode = .countUp
        viewModel.start()
        clock.advance(42)
        viewModel.reset()
        viewModel.mode = .countDown

        #expect(try #require(recorded.first).sessionType == .stopwatch)
    }
}
