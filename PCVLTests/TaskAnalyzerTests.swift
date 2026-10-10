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

    private func session(_ taskID: UUID?, hoursFromStart: Double, minutes: Int) -> TaskSessionItem {
        TaskSessionItem(date: start.addingTimeInterval(hoursFromStart * 3600), duration: minutes * 60, taskID: taskID)
    }

    private var tasks: [TaskItem] {
        [task(idle, "Idle"), task(refactor, "Refactor", done: true), task(report, "Report")]
    }

    private var sessions: [TaskSessionItem] {
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

    @Test func orderedByTotalWithUnworkedTasksAndNoTaskLast() {
        let summaries = analyzer.summaries(tasks: tasks, sessions: sessions)
        #expect(summaries.map(\.title) == ["Report", "Refactor", "Idle", "No task"])
        #expect(summaries.last?.isUntagged == true)
        #expect(summaries.first { $0.taskID == refactor }?.isDone == true)
    }

    @Test func sharesAreOfAllFocusTime() {
        let summaries = analyzer.summaries(tasks: tasks, sessions: sessions)
        let total = 360.0
        #expect(summaries.map(\.share) == [230 / total, 30 / total, 0, 100 / total])
    }

    @Test func noTaskEntryOnlyWhenThereIsUntaggedTime() {
        let tagged = sessions.filter { $0.taskID != nil }
        #expect(!analyzer.summaries(tasks: tasks, sessions: tagged).contains { $0.isUntagged })
    }

    @Test func progressIsARunningTotalFromZero() {
        let points = analyzer.progress(for: report, sessions: sessions.reversed())
        #expect(points.map(\.totalSeconds) == [0, 50 * 60, 230 * 60])
        #expect(points.first?.date == start)
        #expect(points.last?.date == start.addingTimeInterval(22.5 * 3600 + 180 * 60))
        #expect(analyzer.progress(for: idle, sessions: sessions).isEmpty)
    }
}
