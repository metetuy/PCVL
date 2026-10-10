import Foundation
import Combine

// MARK: - Stats Summary View Model

/// Today and the current week, shared by the panel's stats tab and the window's focus
/// screen footer, so "today" is derived one way everywhere: from the week snapshot,
/// with sessions split at hour boundaries like the rest of the analytics.
@MainActor
final class StatsSummaryViewModel: ObservableObject {
    @Published private(set) var week: StatsSnapshot = .empty

    private let statsManager: StatisticsManager
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(statsManager: StatisticsManager, settings: AppSettings) {
        self.statsManager = statsManager
        self.settings = settings
        statsManager.didChange
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
        settings.$statsTimeUnit
            .removeDuplicates()
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        refresh()
    }

    func refresh() {
        week = statsManager.snapshot(range: .week)
    }

    private var today: StatsBucket? { week.buckets.first { $0.isCurrent } }

    var unit: StatsTimeUnit { settings.statsTimeUnit }
    var todayFocusSeconds: Int { today?.focusSeconds ?? 0 }
    var todaySessions: Int { today?.sessions ?? 0 }
    var streak: Int { week.currentStreak }
    var changeText: String? { StatsFormat.changeText(week.changeRatio) }
    var changeIsPositive: Bool { (week.changeRatio ?? 0) >= 0 }

    /// One-line summary for the focus screen footer, including the session in progress.
    func todaySummaryText(inProgressSeconds: Int) -> String {
        let seconds = todayFocusSeconds + inProgressSeconds
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let focus = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        let sessions = todaySessions
        return "Today \(focus) · \(sessions) session\(sessions == 1 ? "" : "s") · \(streak)-day streak"
    }

    func axisLabel(for date: Date) -> String {
        StatsFormat.axisLabel(for: date, component: .day, range: .week)
    }

    func bucketTitle(_ bucket: StatsBucket) -> String {
        StatsFormat.bucketTitle(bucket, component: .day)
    }
}
