import Foundation

// MARK: - Task Session Item

/// A focus session reduced to what task totals need.
struct TaskSessionItem {
    /// The record's `persistentModelID` (any unique value in tests).
    let id: AnyHashable
    let date: Date
    let duration: Int
    let type: SessionType
    /// nil when the session counted toward no task.
    let taskID: UUID?
}

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
    func summaries(tasks: [TaskItem], sessions: [TaskSessionItem]) -> [TaskSummary] {
        let byTask = Dictionary(grouping: sessions, by: \.taskID)
        let allFocus = sessions.reduce(0) { $0 + $1.duration }

        let all = tasks.map { task in
            summary(
                taskID: task.id,
                title: task.title,
                createdAt: task.createdAt,
                completedAt: task.completedAt,
                sessions: byTask[task.id] ?? [],
                allFocus: allFocus
            )
        }
        let open = all.filter { !$0.isDone }
        let started = open.filter { $0.sessions > 0 }.sorted { $0.totalSeconds > $1.totalSeconds }
        let notStarted = open.filter { $0.sessions == 0 }
        let done = all.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        var result = started + notStarted + done
        if let untagged = byTask[nil], !untagged.isEmpty {
            result.append(summary(taskID: nil, title: "No task", createdAt: nil, completedAt: nil, sessions: untagged, allFocus: allFocus))
        }
        return result
    }

    /// The smallest unit (in hours) at which `maxSeconds` fits in `maxBlocks` blocks.
    static func blockUnitHours(maxSeconds: Int, maxBlocks: Int = 60) -> Int {
        let hours = Double(maxSeconds) / 3600
        return blockUnits.first { hours / Double($0) <= Double(maxBlocks) } ?? blockUnits.last!
    }

    private func summary(
        taskID: UUID?,
        title: String,
        createdAt: Date?,
        completedAt: Date?,
        sessions: [TaskSessionItem],
        allFocus: Int
    ) -> TaskSummary {
        let total = sessions.reduce(0) { $0 + $1.duration }
        let dates = sessions.map(\.date)
        return TaskSummary(
            taskID: taskID,
            title: title,
            createdAt: createdAt,
            completedAt: completedAt,
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
