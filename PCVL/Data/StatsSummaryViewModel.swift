import Foundation
import Combine

// MARK: - Stats Summary View Model

/// Backs the concise stats tab in the menu bar panel: today and the current week.
@MainActor
final class StatsSummaryViewModel: ObservableObject {
    @Published private(set) var week: StatsSnapshot = .empty

    private let statsManager: StatisticsManager
    private var cancellables = Set<AnyCancellable>()

    init(statsManager: StatisticsManager) {
        self.statsManager = statsManager
        statsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        refresh()
    }

    func refresh() {
        week = statsManager.snapshot(range: .week)
    }

    private var today: StatsBucket? { week.buckets.first { $0.isCurrent } }

    var todayFocusSeconds: Int { today?.focusSeconds ?? 0 }
    var todaySessions: Int { today?.sessions ?? 0 }
    var streak: Int { week.currentStreak }
    var changeText: String? { StatsFormat.changeText(week.changeRatio) }
    var changeIsPositive: Bool { (week.changeRatio ?? 0) >= 0 }

    func axisLabel(for date: Date) -> String {
        StatsFormat.axisLabel(for: date, component: .day, range: .week)
    }

    func bucketTitle(_ bucket: StatsBucket) -> String {
        StatsFormat.bucketTitle(bucket, component: .day)
    }
}
