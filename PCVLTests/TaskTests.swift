import Foundation
import Testing
@testable import PCVL

/// Tasks and how sessions count toward them, with a controllable clock, an
/// in-memory store and throwaway defaults.
@MainActor
struct TaskTests {
    private final class Clock {
        var now = Date()
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    private let clock = Clock()
    private let defaults: UserDefaults
    private let stats = StatisticsManager(inMemory: true)
    private let taskManager: TaskManager
    private let timer: TimerViewModel
    private let tasks: TasksViewModel

    init() {
        let suite = "PCVLTests.Tasks.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        taskManager = TaskManager(statsManager: stats, defaults: defaults)
        let clock = self.clock
        timer = TimerViewModel(now: { clock.now })
        timer.setStatisticsManager(stats)
        timer.setTaskManager(taskManager)
        tasks = TasksViewModel(taskManager: taskManager, statsManager: stats, timer: timer)
    }

    private func task(_ id: UUID?) throws -> TaskItem {
        let id = try #require(id)
        return try #require((tasks.openTasks + tasks.doneTasks).first { $0.id == id })
    }

    private func runFocus(_ seconds: TimeInterval) {
        timer.start()
        clock.advance(seconds)
        timer.reset()
    }

    @Test func focusSessionsCountTowardTheCurrentTask() throws {
        tasks.addTask("Write report")
        let id = tasks.activeTaskID
        #expect(id != nil, "the first task added becomes current")

        runFocus(300)
        runFocus(120)

        let report = try task(id)
        #expect(report.focusSeconds == 420)
        #expect(report.sessions == 2)
    }

    @Test func breaksNeverCountTowardATask() throws {
        tasks.addTask("Write report")
        timer.start()
        clock.advance(200)
        timer.skipPhase() // records focus, starts the break
        clock.advance(60)
        timer.skipPhase() // records the break

        let report = try task(tasks.activeTaskID)
        #expect(report.focusSeconds == 200)
        #expect(report.sessions == 1)
    }

    @Test func stopwatchSessionsCountTowardTheCurrentTask() throws {
        tasks.addTask("Read paper")
        timer.mode = .countUp
        runFocus(90)
        timer.mode = .countDown

        #expect(try task(tasks.activeTaskID).focusSeconds == 90)
    }

    @Test func currentTaskIsLockedDuringAFocusSessionOnly() throws {
        tasks.addTask("A")
        tasks.addTask("B")
        let a = try #require(tasks.activeTaskID)
        let b = try #require(tasks.openTasks.last?.id)

        timer.start()
        #expect(tasks.isSelectionLocked)
        tasks.select(b)
        #expect(tasks.activeTaskID == a, "ignored while focus runs")

        timer.pause()
        #expect(tasks.isSelectionLocked, "a paused session still counts toward its task")

        timer.start()
        clock.advance(100)
        timer.skipPhase() // the break starts
        #expect(!tasks.isSelectionLocked, "the next task can be picked during a break")
        tasks.select(b)
        #expect(tasks.activeTaskID == b)

        #expect(try task(a).focusSeconds == 100)
        #expect(try task(b).focusSeconds == 0)
    }

    @Test func checkingOffTheCurrentTaskDuringASessionKeepsItsTime() throws {
        tasks.addTask("Ship it")
        let id = try #require(tasks.activeTaskID)

        timer.start()
        clock.advance(150)
        tasks.toggleDone(id)
        #expect(tasks.activeTaskID == nil, "a done task is never current")
        timer.reset()

        let shipped = try task(id)
        #expect(shipped.isDone)
        #expect(shipped.focusSeconds == 150)
        #expect(tasks.doneTasks.map(\.id) == [id])
    }

    @Test func deletingATaskKeepsItsSessionsInStatistics() throws {
        tasks.addTask("Temporary")
        let id = try #require(tasks.activeTaskID)
        runFocus(240)

        tasks.delete(id)

        #expect(!tasks.hasTasks)
        #expect(tasks.activeTaskID == nil)
        let sessions = stats.sessions(from: .distantPast, to: .distantFuture)
        #expect(sessions.map(\.duration) == [240])
        #expect(sessions.first?.task == nil)
    }

    @Test func resettingStatisticsClearsTaskTotals() throws {
        tasks.addTask("Write report")
        let id = tasks.activeTaskID
        runFocus(300)

        stats.deleteAllSessions()

        let report = try task(id)
        #expect(report.focusSeconds == 0)
        #expect(report.sessions == 0)
        #expect(tasks.activeTaskID == id, "tasks themselves are kept")
    }

    @Test func currentTaskIsRestoredOnlyWhileOpen() throws {
        tasks.addTask("A")
        tasks.addTask("B")
        let a = try #require(tasks.activeTaskID)
        let b = try #require(tasks.openTasks.last?.id)

        #expect(TaskManager(statsManager: stats, defaults: defaults).activeTaskID == a)

        tasks.select(b)
        taskManager.setDone(b, true)
        #expect(TaskManager(statsManager: stats, defaults: defaults).activeTaskID == nil)
        #expect(taskManager.activeTaskID == nil)
    }

    @Test func blankTitlesAreIgnored() {
        tasks.addTask("   ")
        #expect(!tasks.hasTasks)
    }
}
