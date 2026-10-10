import Foundation
import SwiftData
import Combine

// MARK: - Focus Task

/// Something the user spends focus sessions on. A task never stores its own time:
/// it is derived from the sessions linked to it, so task totals always agree with
/// the statistics. Named `FocusTask` to stay clear of Swift's concurrency `Task`.
@Model
final class FocusTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    /// Set when the task is checked off; nil while it is open.
    var completedAt: Date?
    /// Deleting a task keeps its sessions; they remain as untagged focus time.
    @Relationship(deleteRule: .nullify, inverse: \SessionRecord.task)
    var sessions: [SessionRecord] = []

    init(title: String, createdAt: Date) {
        self.id = UUID()
        self.title = title
        self.createdAt = createdAt
    }
}

// MARK: - Task Item

/// Value snapshot of a task for the views, with its totals already summed.
struct TaskItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let createdAt: Date
    let completedAt: Date?
    let focusSeconds: Int
    let sessions: Int

    var isDone: Bool { completedAt != nil }
}

extension ModelContext {
    func focusTask(id: UUID) -> FocusTask? {
        var descriptor = FetchDescriptor<FocusTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? fetch(descriptor).first
    }
}

// MARK: - Task Manager

/// SwiftData CRUD for tasks, sharing the statistics store (sessions link to tasks),
/// and the current task that new focus sessions count toward.
@MainActor
final class TaskManager {
    /// Fires after any task change, including the current task.
    let didChange = PassthroughSubject<Void, Never>()

    private let modelContext: ModelContext
    private let defaults: UserDefaults
    private static let activeTaskKey = "activeTaskID"

    /// The task new focus sessions count toward. Always an open task, or nil.
    private(set) var activeTaskID: UUID?

    init(statsManager: StatisticsManager, defaults: UserDefaults = .standard) {
        modelContext = statsManager.modelContainer.mainContext
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.activeTaskKey).flatMap(UUID.init)
        if let stored, let task = modelContext.focusTask(id: stored), task.completedAt == nil {
            activeTaskID = stored
        } else {
            defaults.removeObject(forKey: Self.activeTaskKey)
        }
    }

    // MARK: - Queries

    /// Every task with its totals, in creation order.
    func tasks() -> [TaskItem] {
        let descriptor = FetchDescriptor<FocusTask>(sortBy: [SortDescriptor(\.createdAt)])
        let tasks = (try? modelContext.fetch(descriptor)) ?? []
        return tasks.map { task in
            let focus = task.sessions.filter { $0.sessionType != .shortBreak }
            return TaskItem(
                id: task.id,
                title: task.title,
                createdAt: task.createdAt,
                completedAt: task.completedAt,
                focusSeconds: focus.reduce(0) { $0 + $1.duration },
                sessions: focus.count
            )
        }
    }

    // MARK: - Current Task

    func setActiveTask(_ id: UUID?) {
        if let id, modelContext.focusTask(id: id)?.completedAt != nil { return }
        activeTaskID = id
        defaults.set(id?.uuidString, forKey: Self.activeTaskKey)
        didChange.send()
    }

    // MARK: - Edit

    /// Adds an open task; returns its id, or nil for a blank title.
    @discardableResult
    func addTask(title: String, at date: Date = Date()) -> UUID? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let task = FocusTask(title: title, createdAt: date)
        modelContext.insert(task)
        save()
        return task.id
    }

    func rename(_ id: UUID, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let task = modelContext.focusTask(id: id) else { return }
        task.title = title
        save()
    }

    /// Checking off the current task clears it; its sessions stay with it.
    func setDone(_ id: UUID, _ done: Bool, at date: Date = Date()) {
        guard let task = modelContext.focusTask(id: id) else { return }
        task.completedAt = done ? date : nil
        if done && activeTaskID == id {
            setActiveTask(nil)
        }
        save()
    }

    func delete(_ id: UUID) {
        guard let task = modelContext.focusTask(id: id) else { return }
        modelContext.delete(task)
        if activeTaskID == id {
            setActiveTask(nil)
        }
        save()
    }

    private func save() {
        try? modelContext.save()
        didChange.send()
    }
}
