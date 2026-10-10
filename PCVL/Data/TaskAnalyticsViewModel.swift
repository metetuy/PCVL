import Foundation
import Combine
import SwiftData

// MARK: - Task Analytics View Model

/// The tasks part of the analytics window: all-time totals per task, the selected
/// task's details and running total, and assigning sessions to tasks. Like
/// `AnalyticsViewModel` it only recomputes while the analytics screen is shown.
@MainActor
final class TaskAnalyticsViewModel: ObservableObject {
    @Published private(set) var summaries: [TaskSummary] = []
    @Published private(set) var selectedID: String?
    @Published private(set) var progress: [TaskProgressPoint] = []
    /// Every task (open first, then done), to assign sessions to.
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var totalFocusSeconds = 0

    /// Set by the window controller while the analytics screen is visible.
    var isActive = false {
        didSet {
            if isActive && isStale { refresh() }
        }
    }

    private var isStale = true
    private var sessions: [TaskSessionItem] = []
    private let statsManager: StatisticsManager
    private let taskManager: TaskManager
    private let analyzer = TaskAnalyzer()
    private var cancellables = Set<AnyCancellable>()

    init(statsManager: StatisticsManager, taskManager: TaskManager) {
        self.statsManager = statsManager
        self.taskManager = taskManager
        Publishers.Merge(statsManager.didChange, taskManager.didChange)
            .sink { [weak self] in self?.storeDidChange() }
            .store(in: &cancellables)
    }

    func refresh() {
        let allTasks = taskManager.tasks()
        tasks = allTasks.filter { !$0.isDone } + allTasks.filter(\.isDone)
        sessions = statsManager.focusSessionItems()
        summaries = analyzer.summaries(tasks: allTasks, sessions: sessions)
        totalFocusSeconds = sessions.reduce(0) { $0 + $1.duration }
        if selectedID == nil || !summaries.contains(where: { $0.id == selectedID }) {
            selectedID = summaries.first(where: { $0.sessions > 0 })?.id ?? summaries.first?.id
        }
        updateProgress()
        isStale = false
    }

    private func storeDidChange() {
        if isActive {
            refresh()
        } else {
            isStale = true
        }
    }

    private func updateProgress() {
        progress = selected.map { analyzer.progress(for: $0.taskID, sessions: sessions) } ?? []
    }

    // MARK: - Selection

    var selected: TaskSummary? {
        summaries.first { $0.id == selectedID }
    }

    func select(_ id: String) {
        guard id != selectedID else { return }
        selectedID = id
        updateProgress()
    }

    /// The bar length of a task in the list, relative to the largest entry.
    func barFraction(_ summary: TaskSummary) -> Double {
        let largest = summaries.map(\.totalSeconds).max() ?? 0
        return largest > 0 ? Double(summary.totalSeconds) / Double(largest) : 0
    }

    var untagged: TaskSummary? { summaries.first(where: \.isUntagged) }
    var hasTasks: Bool { !tasks.isEmpty }

    func title(for taskID: UUID?) -> String? {
        guard let taskID else { return nil }
        return tasks.first { $0.id == taskID }?.title
    }

    // MARK: - Assigning

    /// Moves every focus session without a task onto `taskID`.
    func assignUntagged(to taskID: UUID) {
        statsManager.assignUntaggedSessions(toTask: taskID)
        selectedID = taskID.uuidString
        refresh()
    }

    /// Moves one focus session onto a task, or with nil removes its task.
    func assign(_ session: StatsSessionItem, to taskID: UUID?) {
        guard session.isFocus, let id = session.id.base as? PersistentIdentifier else { return }
        statsManager.assignSession(id, toTask: taskID)
    }

    // MARK: - Display

    func durationText(_ seconds: Int) -> String { StatsFormat.hoursMinutes(seconds) }

    func shareText(_ summary: TaskSummary) -> String { StatsFormat.percentText(summary.share) }

    func lastWorkedText(_ summary: TaskSummary) -> String {
        summary.lastDate.map(StatsFormat.sessionDate) ?? "—"
    }

    func firstWorkedText(_ summary: TaskSummary) -> String {
        summary.firstDate.map(StatsFormat.shortDate) ?? "—"
    }
}
