import Foundation

// MARK: - Task Session Item

/// A focus session reduced to what task totals need.
struct TaskSessionItem {
    let date: Date
    let duration: Int
    /// nil when the session counted toward no task.
    let taskID: UUID?
}

// MARK: - Task Summary

/// All-time totals of one task, or (with a nil `taskID`) of the focus time that
/// has no task.
struct TaskSummary: Identifiable, Equatable {
    let taskID: UUID?
    let title: String
    let isDone: Bool
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
    var averageSeconds: Int { sessions > 0 ? totalSeconds / sessions : 0 }
}

/// The running total of a task after one of its sessions.
struct TaskProgressPoint: Identifiable, Equatable {
    let id: Int
    let date: Date
    let totalSeconds: Int
}

// MARK: - Task Analyzer

/// Pure all-time aggregation per task. A task's time is the plain sum of its
/// sessions: no periods, no hour or day splitting.
struct TaskAnalyzer {
    var calendar = Calendar.current

    /// Every task (ordered by total focus, most first; tasks without sessions keep
    /// their order after them), then the focus time without a task, if any.
    func summaries(tasks: [TaskItem], sessions: [TaskSessionItem]) -> [TaskSummary] {
        let byTask = Dictionary(grouping: sessions, by: \.taskID)
        let allFocus = sessions.reduce(0) { $0 + $1.duration }

        let taskSummaries = tasks.map { task in
            summary(taskID: task.id, title: task.title, isDone: task.isDone, sessions: byTask[task.id] ?? [], allFocus: allFocus)
        }
        let worked = taskSummaries.filter { $0.sessions > 0 }.sorted { $0.totalSeconds > $1.totalSeconds }
        let unworked = taskSummaries.filter { $0.sessions == 0 }

        var result = worked + unworked
        if let untagged = byTask[nil], !untagged.isEmpty {
            result.append(summary(taskID: nil, title: "No task", isDone: false, sessions: untagged, allFocus: allFocus))
        }
        return result
    }

    /// Running total after each session of `taskID` (nil = no task), in order,
    /// starting from zero at the first session's start.
    func progress(for taskID: UUID?, sessions: [TaskSessionItem]) -> [TaskProgressPoint] {
        let own = sessions.filter { $0.taskID == taskID }.sorted { $0.date < $1.date }
        guard let first = own.first else { return [] }
        var total = 0
        var points = [TaskProgressPoint(id: 0, date: first.date, totalSeconds: 0)]
        for (index, session) in own.enumerated() {
            total += session.duration
            points.append(TaskProgressPoint(
                id: index + 1,
                date: session.date.addingTimeInterval(TimeInterval(session.duration)),
                totalSeconds: total
            ))
        }
        return points
    }

    private func summary(taskID: UUID?, title: String, isDone: Bool, sessions: [TaskSessionItem], allFocus: Int) -> TaskSummary {
        let total = sessions.reduce(0) { $0 + $1.duration }
        let dates = sessions.map(\.date)
        return TaskSummary(
            taskID: taskID,
            title: title,
            isDone: isDone,
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
