import Foundation
import Testing
@testable import PCVL

/// All-time task totals: plain sums of sessions, independent of days and hours.
struct TaskAnalyzerTests {
    private let analyzer = TaskAnalyzer()
    private let start = Date(timeIntervalSince1970: 1_790_000_000)
    private let report = UUID()
    private let refactor = UUID()
    private let idle = UUID()

    private func task(_ id: UUID, _ title: String, done: Bool = false) -> TaskItem {
        TaskItem(id: id, title: title, createdAt: start, completedAt: done ? start : nil, focusSeconds: 0, sessions: 0)
    }

    private func session(_ taskID: UUID?, hoursFromStart: Double, minutes: Int) -> StatsSessionItem {
        StatsSessionItem(
            id: UUID(),
            date: start.addingTimeInterval(hoursFromStart * 3600),
            duration: minutes * 60,
            type: .work,
            taskID: taskID
        )
    }

    private var tasks: [TaskItem] {
        [task(idle, "Idle"), task(refactor, "Refactor", done: true), task(report, "Report")]
    }

    private var sessions: [StatsSessionItem] {
        [
            session(report, hoursFromStart: 0, minutes: 50),
            // Crosses midnight and an hour boundary: still one plain 3h block.
            session(report, hoursFromStart: 22.5, minutes: 180),
            session(refactor, hoursFromStart: 1, minutes: 30),
            session(nil, hoursFromStart: 2, minutes: 100)
        ]
    }

    @Test func totalsAreThePlainSumOfSessions() throws {
        let summaries = analyzer.summaries(tasks: tasks, sessions: sessions)
        let reportSummary = try #require(summaries.first { $0.taskID == report })
        #expect(reportSummary.totalSeconds == 230 * 60)
        #expect(reportSummary.sessions == 2)
        #expect(reportSummary.longestSeconds == 180 * 60)
        #expect(reportSummary.averageSeconds == 115 * 60)
        #expect(reportSummary.firstDate == start)
        #expect(reportSummary.activeDays == 2)
    }

    @Test func openTasksFirstThenDoneThenNoTask() {
        let summaries = analyzer.summaries(tasks: tasks, sessions: sessions)
        #expect(summaries.map(\.title) == ["Report", "Idle", "Refactor", "No task"])
        #expect(summaries.last?.isUntagged == true)
        #expect(summaries.first { $0.taskID == refactor }?.isDone == true)
    }

    @Test func sharesAreOfAllFocusTime() {
        let summaries = analyzer.summaries(tasks: tasks, sessions: sessions)
        let total = 360.0
        #expect(summaries.map(\.share) == [230 / total, 0, 30 / total, 100 / total])
    }

    @Test func noTaskEntryOnlyWhenThereIsUntaggedTime() {
        let tagged = sessions.filter { $0.taskID != nil }
        #expect(!analyzer.summaries(tasks: tasks, sessions: tagged).contains { $0.isUntagged })
    }

    @Test func doneTasksCarryTheirDates() throws {
        let refactorSummary = try #require(analyzer.summaries(tasks: tasks, sessions: sessions).first { $0.taskID == refactor })
        #expect(refactorSummary.createdAt == start)
        #expect(refactorSummary.completedAt == start)
        #expect(refactorSummary.isDone)
    }

    @Test func blockUnitKeepsTheLargestTotalWithinSixtyBlocks() {
        #expect(TaskAnalyzer.blockUnitHours(maxSeconds: 0) == 1)
        #expect(TaskAnalyzer.blockUnitHours(maxSeconds: 52 * 3600) == 1)
        #expect(TaskAnalyzer.blockUnitHours(maxSeconds: 61 * 3600) == 2)
        #expect(TaskAnalyzer.blockUnitHours(maxSeconds: 400 * 3600) == 10)
    }

    @Test func menuTitlesTellSameNamedTasksApart() {
        let first = TaskItem(id: UUID(), title: "Write", createdAt: start, completedAt: start.addingTimeInterval(86400), focusSeconds: 0, sessions: 0)
        let second = TaskItem(id: UUID(), title: "Write", createdAt: start.addingTimeInterval(86400 * 3), completedAt: nil, focusSeconds: 0, sessions: 0)
        let other = TaskItem(id: UUID(), title: "Read", createdAt: start, completedAt: nil, focusSeconds: 0, sessions: 0)
        let all = [first, second, other]
        #expect(TasksViewModel.menuTitle(for: other, among: all) == "Read")
        #expect(TasksViewModel.menuTitle(for: second, among: all).hasPrefix("Write (created "))
        #expect(TasksViewModel.menuTitle(for: first, among: all).hasPrefix("Write (done · created "))
        #expect(TasksViewModel.menuTitle(for: first, among: all) != TasksViewModel.menuTitle(for: second, among: all))
    }
}
