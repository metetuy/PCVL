import Foundation

// MARK: - Task Summary

/// All-time totals of one task, or (with a nil `taskID`) of the focus time that
/// has no task.
struct TaskSummary: Identifiable, Equatable {
    let taskID: UUID?
    let title: String
    let createdAt: Date?
    let completedAt: Date?
    let totalSeconds: Int
    let sessions: Int
    let longestSeconds: Int
    let firstDate: Date?
    let lastDate: Date?
    let activeDays: Int
    /// Share of all focus time ever recorded, 0...1.
    let share: Double

    static let untaggedID = "untagged"

    var id: String { taskID?.uuidString ?? Self.untaggedID }
    var isUntagged: Bool { taskID == nil }
    var isDone: Bool { completedAt != nil }
    var averageSeconds: Int { sessions > 0 ? totalSeconds / sessions : 0 }
}

// MARK: - Task Analyzer

/// Pure all-time aggregation per task. A task's time is the plain sum of its
/// sessions: no periods, no hour or day splitting.
struct TaskAnalyzer {
    var calendar = Calendar.current

    /// Hours one block stands for, so the largest total fits in `maxBlocks`.
    static let blockUnits = [1, 2, 5, 10, 25, 50, 100, 250, 500, 1000]

    /// Open tasks (most focus first, then the ones not started), then done tasks
    /// (most recently finished first), then the focus time without a task, if any.
    func summaries(tasks: [TaskItem], sessions: [StatsSessionItem]) -> [TaskSummary] {
        let byTask = Dictionary(grouping: sessions, by: \.taskID)
        let allFocus = sessions.reduce(0) { $0 + $1.duration }
        func summary(of task: TaskItem?) -> TaskSummary {
            makeSummary(of: task, sessions: byTask[task?.id] ?? [], allFocus: allFocus)
        }

        let open = tasks.filter { !$0.isDone }.map(summary(of:))
        let started = open.filter { $0.sessions > 0 }.sorted { $0.totalSeconds > $1.totalSeconds }
        let notStarted = open.filter { $0.sessions == 0 }
        let done = tasks.filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .map(summary(of:))

        let untagged = byTask[nil] ?? []
        return started + notStarted + done + (untagged.isEmpty ? [] : [summary(of: nil)])
    }

    /// The smallest unit (in hours) at which `maxSeconds` fits in `maxBlocks` blocks.
    static func blockUnitHours(maxSeconds: Int, maxBlocks: Int = 60) -> Int {
        let hours = Double(maxSeconds) / 3600
        return blockUnits.first { hours / Double($0) <= Double(maxBlocks) } ?? blockUnits.last!
    }

    /// `task` nil summarizes the focus time without a task.
    private func makeSummary(of task: TaskItem?, sessions: [StatsSessionItem], allFocus: Int) -> TaskSummary {
        let total = sessions.reduce(0) { $0 + $1.duration }
        let dates = sessions.map(\.date)
        return TaskSummary(
            taskID: task?.id,
            title: task?.title ?? "No task",
            createdAt: task?.createdAt,
            completedAt: task?.completedAt,
            totalSeconds: total,
            sessions: sessions.count,
            longestSeconds: sessions.map(\.duration).max() ?? 0,
            firstDate: dates.min(),
            lastDate: dates.max(),
            activeDays: Set(dates.map { calendar.startOfDay(for: $0) }).count,
            share: allFocus > 0 ? Double(total) / Double(allFocus) : 0
        )
    }
}
