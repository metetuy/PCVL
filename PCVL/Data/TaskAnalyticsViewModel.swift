import Foundation
import Combine
import SwiftData

// MARK: - Task Analytics View Model

/// The tasks part of the analytics window: a card per task with its all-time total
/// drawn as hour blocks, the sessions behind the selected card, and assigning
/// sessions to tasks. Like `AnalyticsViewModel` it only recomputes while the
/// analytics screen is shown.
@MainActor
final class TaskAnalyticsViewModel: ObservableObject {
    @Published private(set) var summaries: [TaskSummary] = []
    @Published private(set) var selectedID: String?
    /// Every task (open first, then done), to assign sessions to.
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var activeTaskID: UUID?
    @Published private(set) var totalFocusSeconds = 0
    /// Hours one block stands for, shared by every card so they compare at a glance.
    @Published private(set) var blockUnitHours = 1

    /// Set by the window controller while the analytics screen is visible.
    var isActive = false {
        didSet {
            if isActive && isStale { refresh() }
        }
    }

    private var isStale = true
    private var sessions: [StatsSessionItem] = []
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
        activeTaskID = taskManager.activeTaskID
        sessions = statsManager.focusSessionItems()
        summaries = analyzer.summaries(tasks: allTasks, sessions: sessions)
        totalFocusSeconds = sessions.reduce(0) { $0 + $1.duration }
        blockUnitHours = TaskAnalyzer.blockUnitHours(maxSeconds: summaries.map(\.totalSeconds).max() ?? 0)
        if let selectedID, !summaries.contains(where: { $0.id == selectedID }) {
            self.selectedID = nil
        }
        isStale = false
    }

    private func storeDidChange() {
        if isActive {
            refresh()
        } else {
            isStale = true
        }
    }

    // MARK: - Selection

    var selected: TaskSummary? {
        summaries.first { $0.id == selectedID }
    }

    /// Selecting the selected card again closes its sessions.
    func toggleSelection(_ id: String) {
        selectedID = selectedID == id ? nil : id
    }

    /// The sessions behind the selected card, newest first.
    var selectedSessions: [StatsSessionItem] {
        guard let selected else { return [] }
        return sessions.filter { $0.taskID == selected.taskID }.reversed()
    }

    // MARK: - Totals

    var untagged: TaskSummary? { summaries.first(where: \.isUntagged) }
    var hasTasks: Bool { !tasks.isEmpty }
    var untaggedSeconds: Int { untagged?.totalSeconds ?? 0 }
    var taggedSeconds: Int { totalFocusSeconds - untaggedSeconds }

    /// A card's total in blocks of `blockUnitHours`; the fraction is the last,
    /// partly filled block.
    func blocks(for summary: TaskSummary) -> Double {
        Double(summary.totalSeconds) / 3600 / Double(blockUnitHours)
    }

    var blockLegend: String {
        blockUnitHours == 1 ? "1 block = 1 hour" : "1 block = \(blockUnitHours) hours"
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

    func title(for taskID: UUID?) -> String? {
        guard let taskID else { return nil }
        return tasks.first { $0.id == taskID }?.title
    }

    func menuTitle(for task: TaskItem) -> String {
        TasksViewModel.menuTitle(for: task, among: tasks)
    }

    /// The card's footer: when the task was created and finished or last worked on.
    func datesText(for summary: TaskSummary) -> String {
        if summary.isUntagged {
            guard let first = summary.firstDate, let last = summary.lastDate else { return "" }
            return "\(StatsFormat.dayText(first)) – \(StatsFormat.dayText(last))"
        }
        guard let created = summary.createdAt else { return "" }
        let dates = TasksViewModel.datesText(created: created, completed: summary.completedAt)
        guard !summary.isDone, let last = summary.lastDate else { return dates }
        return "\(dates) · Last \(StatsFormat.sessionDate(last))"
    }

    func detailText(for summary: TaskSummary) -> String {
        guard summary.sessions > 0 else { return "No sessions yet" }
        return [
            StatsFormat.sessionCount(summary.sessions),
            "avg \(StatsFormat.hoursMinutes(summary.averageSeconds))",
            "longest \(StatsFormat.hoursMinutes(summary.longestSeconds))",
            "\(summary.activeDays) active day\(summary.activeDays == 1 ? "" : "s")",
            "\(StatsFormat.percentText(summary.share)) of all focus"
        ].joined(separator: " · ")
    }
}
