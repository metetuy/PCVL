import Foundation
import Combine

// MARK: - Analytics View Model

/// Drives the analytics window: selected range, period navigation and time unit.
/// Recomputes once per change instead of on every render.
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var snapshot: StatsSnapshot = .empty

    @Published var range: StatsRange {
        didSet {
            guard range != oldValue else { return }
            UserDefaults.standard.set(range.rawValue, forKey: Self.rangeKey)
            offset = 0
            refresh()
        }
    }

    @Published var unit: StatsTimeUnit {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: StatsTimeUnit.storageKey) }
    }

    /// 0 = current period, -1 = previous one, and so on.
    @Published private(set) var offset: Int = 0

    private let statsManager: StatisticsManager
    private var cancellables = Set<AnyCancellable>()

    private static let rangeKey = "statsRange"

    init(statsManager: StatisticsManager) {
        self.statsManager = statsManager
        range = StatsRange(rawValue: UserDefaults.standard.string(forKey: Self.rangeKey) ?? "") ?? .week
        unit = .stored

        // objectWillChange fires right after a save; recompute on the next run loop pass.
        statsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    func refresh() {
        snapshot = statsManager.snapshot(range: range, offset: offset)
    }

    // MARK: - Navigation

    var canGoBack: Bool { range.supportsNavigation }
    var canGoForward: Bool { range.supportsNavigation && offset < 0 }
    var isCurrentPeriod: Bool { offset == 0 }

    func goBack() {
        guard canGoBack else { return }
        offset -= 1
        refresh()
    }

    func goForward() {
        guard canGoForward else { return }
        offset += 1
        refresh()
    }

    func goToCurrent() {
        guard offset != 0 else { return }
        offset = 0
        refresh()
    }

    // MARK: - Display

    var periodTitle: String { StatsFormat.periodTitle(for: snapshot, offset: offset) }
    var changeText: String? { StatsFormat.changeText(snapshot.changeRatio) }
    var changeIsPositive: Bool { (snapshot.changeRatio ?? 0) >= 0 }

    func format(_ seconds: Int) -> String { unit.format(seconds) }

    func axisLabel(for date: Date) -> String {
        StatsFormat.axisLabel(for: date, component: snapshot.bucketComponent, range: range)
    }

    func bucketTitle(_ bucket: StatsBucket) -> String {
        StatsFormat.bucketTitle(bucket, component: snapshot.bucketComponent)
    }
}
