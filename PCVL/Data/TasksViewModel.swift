import Foundation
import Combine

// MARK: - Tasks View Model

/// Tasks for every surface (the window's tasks screen, the task picker in the panel
/// and on the focus screen, the context menu): open and done lists with their
/// totals, the current task, and whether it can change right now.
@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var openTasks: [TaskItem] = []
    @Published private(set) var doneTasks: [TaskItem] = []
    @Published private(set) var activeTaskID: UUID?
    /// True while a focus session runs or is paused: it keeps counting toward the
    /// task it started with, so the current task cannot change until it ends.
    @Published private(set) var isSelectionLocked = false

    private let taskManager: TaskManager
    private var cancellables = Set<AnyCancellable>()

    init(taskManager: TaskManager, statsManager: StatisticsManager, timer: TimerViewModel) {
        self.taskManager = taskManager
        // Recorded (or reset) sessions change the totals.
        Publishers.Merge(taskManager.didChange, statsManager.didChange)
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
        // Built from the published values: `@Published` emits before the property
        // changes, so reading the timer back here would see the old state.
        timer.$engine.map(\.state).combineLatest(timer.$isBreak)
            .map { TimerViewModel.isFocusSessionInProgress(state: $0, isBreak: $1) }
            .removeDuplicates()
            .sink { [weak self] in self?.isSelectionLocked = $0 }
            .store(in: &cancellables)
        refresh()
    }

    func refresh() {
        let tasks = taskManager.tasks()
        openTasks = tasks.filter { !$0.isDone }
        doneTasks = tasks
            .filter(\.isDone)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        activeTaskID = taskManager.activeTaskID
    }

    var activeTask: TaskItem? {
        guard let activeTaskID else { return nil }
        return openTasks.first { $0.id == activeTaskID }
    }

    var hasTasks: Bool { !openTasks.isEmpty || !doneTasks.isEmpty }

    // MARK: - Actions

    /// Ignored while a focus session is in progress (see `isSelectionLocked`).
    func select(_ id: UUID?) {
        guard !isSelectionLocked else { return }
        taskManager.setActiveTask(id)
    }

    /// Adds a task; the first one added while none is current becomes current.
    func addTask(_ title: String) {
        guard let id = taskManager.addTask(title: title) else { return }
        if activeTaskID == nil {
            select(id)
        }
    }

    func rename(_ id: UUID, to title: String) {
        taskManager.rename(id, to: title)
    }

    func toggleDone(_ id: UUID) {
        let isDone = doneTasks.contains { $0.id == id }
        taskManager.setDone(id, !isDone)
    }

    func delete(_ id: UUID) {
        taskManager.delete(id)
    }

    // MARK: - Display

    /// e.g. "1h 20m · 3 sessions", or "No sessions yet"; `compact` (panel rows)
    /// gives only the time, e.g. "1h 20m", or "—".
    static func totalsText(seconds: Int, sessions: Int, compact: Bool = false) -> String {
        guard sessions > 0 || seconds > 0 else { return compact ? "—" : "No sessions yet" }
        if compact { return StatsFormat.hoursMinutes(seconds) }
        return "\(StatsFormat.hoursMinutes(seconds)) · \(StatsFormat.sessionCount(sessions))"
    }

    /// When a done task was created and finished, e.g. "Created Oct 3 · Done Oct 9",
    /// so tasks with the same title stay apart.
    static func datesText(created: Date, completed: Date?) -> String {
        let createdText = "Created \(StatsFormat.dayText(created))"
        guard let completed else { return createdText }
        return "\(createdText) · Done \(StatsFormat.dayText(completed))"
    }

    /// A task's title in menus: done tasks, and tasks whose title another task
    /// shares, get their creation day so the entries can be told apart.
    static func menuTitle(for task: TaskItem, among tasks: [TaskItem]) -> String {
        let isShared = tasks.contains { $0.id != task.id && $0.title == task.title }
        let created = StatsFormat.dayText(task.createdAt)
        if task.isDone {
            return "\(task.title) (done · created \(created))"
        }
        return isShared ? "\(task.title) (created \(created))" : task.title
    }

    /// Menu title among every task (open and done).
    func menuTitle(for task: TaskItem) -> String {
        Self.menuTitle(for: task, among: openTasks + doneTasks)
    }
}
