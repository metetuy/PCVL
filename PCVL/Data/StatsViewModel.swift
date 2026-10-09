import Foundation
import Combine

// MARK: - Stats View Model

/// Drives the statistics screen: selected range, period navigation, time unit, and
/// the aggregated snapshot. Recomputes once per change instead of on every render.
@MainActor
final class StatsViewModel: ObservableObject {
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
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: Self.unitKey) }
    }

    /// 0 = current period, -1 = previous one, and so on.
    @Published private(set) var offset: Int = 0

    private let statsManager: StatisticsManager
    private var cancellables = Set<AnyCancellable>()

    private static let rangeKey = "statsRange"
    private static let unitKey = "statsTimeUnit"

    init(statsManager: StatisticsManager) {
        self.statsManager = statsManager
        let defaults = UserDefaults.standard
        range = StatsRange(rawValue: defaults.string(forKey: Self.rangeKey) ?? "") ?? .week
        unit = StatsTimeUnit(rawValue: defaults.string(forKey: Self.unitKey) ?? "") ?? .minutes

        // objectWillChange fires right after a save; recompute on the next run loop pass.
        statsManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    // MARK: - Actions

    func refresh() {
        let analyzer = StatsAnalyzer()
        let earliest = statsManager.firstSessionDate()
        let period = analyzer.interval(for: range, offset: offset, earliest: earliest)

        // One fetch covers both this period and the previous one used for comparison.
        let fetchStart: Date
        if range.supportsNavigation {
            fetchStart = analyzer.interval(for: range, offset: offset - 1, earliest: earliest).start
        } else {
            fetchStart = period.start
        }
        let sessions = statsManager.sessions(
            from: fetchStart.addingTimeInterval(-StatsAnalyzer.spilloverLookback),
            to: period.end
        )

        snapshot = analyzer.snapshot(
            range: range,
            offset: offset,
            earliest: earliest,
            sessions: sessions,
            previousSessions: range.supportsNavigation ? sessions : nil,
            focusDays: statsManager.focusDays()
        )
    }

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

    func toggleUnit() {
        unit = unit == .minutes ? .hours : .minutes
    }

    // MARK: - Formatting

    func format(_ seconds: Int) -> String {
        unit.format(seconds)
    }

    func chartValue(_ seconds: Int) -> Double {
        unit.value(seconds)
    }

    var periodTitle: String {
        let interval = snapshot.interval
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let sameYear = calendar.component(.year, from: interval.start) == currentYear

        switch range {
        case .day:
            if offset == 0 { return "Today" }
            if offset == -1 { return "Yesterday" }
            return interval.start.formatted(
                sameYear
                    ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
                    : .dateTime.month(.abbreviated).day().year()
            )
        case .week:
            let last = interval.end.addingTimeInterval(-1)
            let startText = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let endText = calendar.isDate(interval.start, equalTo: last, toGranularity: .month)
                ? last.formatted(.dateTime.day())
                : last.formatted(.dateTime.month(.abbreviated).day())
            let base = "\(startText) – \(endText)"
            return sameYear ? base : "\(base), \(calendar.component(.year, from: interval.start))"
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .year:
            return interval.start.formatted(.dateTime.year())
        case .all:
            guard let first = snapshot.sessions.last?.date ?? statsManager.firstSessionDate() else {
                return "All time"
            }
            return "Since \(first.formatted(.dateTime.month(.abbreviated).year()))"
        }
    }

    /// Detailed label for a hovered bar.
    func bucketTitle(_ bucket: StatsBucket) -> String {
        let start = bucket.interval.start
        switch snapshot.bucketComponent {
        case .hour:
            let end = bucket.interval.end
            return "\(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))"
        case .day:
            return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        default:
            return start.formatted(.dateTime.year())
        }
    }

    /// Short x-axis label for a bar start date.
    func axisLabel(for date: Date) -> String {
        switch snapshot.bucketComponent {
        case .hour:
            return Self.hourFormatter.string(from: date)
        case .day:
            return range == .week
                ? date.formatted(.dateTime.weekday(.abbreviated))
                : date.formatted(.dateTime.day())
        case .month:
            return range == .year
                ? date.formatted(.dateTime.month(.narrow))
                : date.formatted(.dateTime.month(.abbreviated))
        default:
            return date.formatted(.dateTime.year())
        }
    }

    /// Number of x-axis labels that fit for the current bucket size.
    func axisLabelStride(compact: Bool) -> Int {
        let count = snapshot.buckets.count
        let target = compact ? 7 : 16
        return max(1, Int((Double(count) / Double(target)).rounded(.up)))
    }

    var changeText: String? {
        guard let ratio = snapshot.changeRatio else { return nil }
        let percent = Int((ratio * 100).rounded())
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(percent)%"
    }

    var changeIsPositive: Bool { (snapshot.changeRatio ?? 0) >= 0 }

    var comparisonLabel: String { range.previousLabel }

    var peakHourText: String {
        guard let hour = snapshot.peakHour else { return "—" }
        return String(format: "%02d:00", hour)
    }

    var peakWeekdayText: String {
        guard let index = snapshot.peakWeekday else { return "—" }
        return Self.weekdayNames[index]
    }

    var bestDayText: String {
        guard let best = snapshot.bestDay else { return "—" }
        return best.date.formatted(.dateTime.month(.abbreviated).day())
    }

    var activeDaysText: String {
        "\(snapshot.activeDays)/\(snapshot.elapsedDays)"
    }

    var focusShareText: String {
        guard let share = snapshot.focusShare else { return "—" }
        return "\(Int((share * 100).rounded()))%"
    }

    func sessionDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = Self.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())), \(time)"
    }

    func sessionDurationText(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter
    }()

    static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let weekdayInitials = ["M", "T", "W", "T", "F", "S", "S"]
}
