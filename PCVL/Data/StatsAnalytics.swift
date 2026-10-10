import Foundation

// MARK: - Range

/// Period the statistics screen aggregates over.
enum StatsRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All"
        }
    }

    /// Label used for the "vs previous period" comparison.
    var previousLabel: String {
        switch self {
        case .day: return "vs prev. day"
        case .week: return "vs last week"
        case .month: return "vs last month"
        case .year: return "vs last year"
        case .all: return ""
        }
    }

    var supportsNavigation: Bool { self != .all }
}

// MARK: - Time Unit

/// Unit used to present focus time: minute based or hour based.
enum StatsTimeUnit: String, CaseIterable, Identifiable {
    case minutes
    case hours

    var id: String { rawValue }

    /// UserDefaults key shared by the panel and the analytics window.
    static let storageKey = "statsTimeUnit"

    static var stored: StatsTimeUnit {
        StatsTimeUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .minutes
    }

    var symbol: String {
        switch self {
        case .minutes: return "m"
        case .hours: return "h"
        }
    }

    var axisTitle: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    func value(_ seconds: Int) -> Double {
        switch self {
        case .minutes: return Double(seconds) / 60
        case .hours: return Double(seconds) / 3600
        }
    }

    /// Formats a duration in this unit, e.g. "1,250m" or "20.8h".
    func format(_ seconds: Int) -> String {
        switch self {
        case .minutes:
            let minutes = Int((Double(seconds) / 60).rounded())
            return "\(minutes.formatted())m"
        case .hours:
            let hours = Double(seconds) / 3600
            let fraction = hours >= 100 ? 0...0 : 0...1
            return "\(hours.formatted(.number.precision(.fractionLength(fraction))))h"
        }
    }

    /// Formats a raw axis value already expressed in this unit.
    func formatAxis(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1))))\(symbol)"
    }
}

// MARK: - Snapshot Types

/// Value copy of a `SessionRecord`, safe to keep around after the store changes;
/// also the analyzer's input, so aggregation never touches the store.
struct StatsSessionItem: Identifiable {
    let id: Int
    let date: Date
    let duration: Int
    let type: SessionType

    var isFocus: Bool { type != .shortBreak }
}

/// One bar in the main chart (an hour, day, month or year).
struct StatsBucket: Identifiable {
    let id: Int
    let interval: DateInterval
    var workSeconds: Int = 0
    var stopwatchSeconds: Int = 0
    var breakSeconds: Int = 0
    var sessions: Int = 0
    let isCurrent: Bool
    let isFuture: Bool

    var focusSeconds: Int { workSeconds + stopwatchSeconds }
}

/// Everything the statistics screen shows for one period, computed in a single pass.
struct StatsSnapshot {
    var range: StatsRange
    var interval: DateInterval
    var bucketComponent: Calendar.Component
    var buckets: [StatsBucket]
    /// Focus seconds by hour of day (0–23).
    var hourly: [Int]
    /// Focus seconds by weekday, Monday first.
    var weekday: [Int]
    var workSeconds: Int
    var stopwatchSeconds: Int
    var breakSeconds: Int
    var focusSessionCount: Int
    var breakSessionCount: Int
    var longestSessionSeconds: Int
    var elapsedDays: Int
    var activeDays: Int
    var bestDay: (date: Date, seconds: Int)?
    var previousFocusSeconds: Int?
    var currentStreak: Int
    var longestStreak: Int
    /// Sessions that started in the period, newest first.
    var sessions: [StatsSessionItem]

    static let empty = StatsSnapshot(
        range: .week,
        interval: DateInterval(start: Date(), duration: 0),
        bucketComponent: .day,
        buckets: [],
        hourly: Array(repeating: 0, count: 24),
        weekday: Array(repeating: 0, count: 7),
        workSeconds: 0,
        stopwatchSeconds: 0,
        breakSeconds: 0,
        focusSessionCount: 0,
        breakSessionCount: 0,
        longestSessionSeconds: 0,
        elapsedDays: 0,
        activeDays: 0,
        bestDay: nil,
        previousFocusSeconds: nil,
        currentStreak: 0,
        longestStreak: 0,
        sessions: []
    )

    var focusSeconds: Int { workSeconds + stopwatchSeconds }

    var averageSessionSeconds: Int {
        focusSessionCount > 0 ? focusSeconds / focusSessionCount : 0
    }

    var dailyAverageSeconds: Int {
        elapsedDays > 0 ? focusSeconds / elapsedDays : 0
    }

    /// Mean focus per bucket that has already started — drawn as the chart's average line.
    var bucketAverageSeconds: Int {
        let elapsed = buckets.filter { !$0.isFuture }
        guard !elapsed.isEmpty else { return 0 }
        return elapsed.reduce(0) { $0 + $1.focusSeconds } / elapsed.count
    }

    /// Hour of day with the most focus time, if any focus was recorded.
    var peakHour: Int? {
        guard let peak = hourly.max(), peak > 0 else { return nil }
        return hourly.firstIndex(of: peak)
    }

    /// Weekday index (Monday = 0) with the most focus time.
    var peakWeekday: Int? {
        guard let peak = weekday.max(), peak > 0 else { return nil }
        return weekday.firstIndex(of: peak)
    }

    /// Relative change versus the previous period, nil when there is nothing to compare.
    var changeRatio: Double? {
        guard let previous = previousFocusSeconds, previous > 0 else { return nil }
        return Double(focusSeconds - previous) / Double(previous)
    }

    /// Share of tracked time spent focusing rather than on breaks.
    var focusShare: Double? {
        let total = focusSeconds + breakSeconds
        return total > 0 ? Double(focusSeconds) / Double(total) : nil
    }
}

// MARK: - Analyzer

/// Pure aggregation over session records — no store access, no side effects.
/// Weeks run Monday–Sunday to match the rest of the app.
struct StatsAnalyzer {
    let calendar: Calendar
    let now: Date

    /// Sessions that start this long before a period may still spill into it.
    static let spilloverLookback: TimeInterval = 2 * 24 * 3600

    init(now: Date = Date(), calendar: Calendar = .current) {
        var cal = calendar
        cal.firstWeekday = 2
        self.calendar = cal
        self.now = now
    }

    // MARK: Periods

    func interval(for range: StatsRange, offset: Int, earliest: Date?) -> DateInterval {
        switch range {
        case .day:
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.dateInterval(of: .day, for: start) ?? DateInterval(start: start, duration: 86_400)
        case .week:
            return shiftedInterval(.weekOfYear, offset: offset)
        case .month:
            return shiftedInterval(.month, offset: offset)
        case .year:
            return shiftedInterval(.year, offset: offset)
        case .all:
            let component = allTimeBucketComponent(earliest: earliest)
            let first = earliest ?? now
            let start = calendar.dateInterval(of: component, for: first)?.start ?? calendar.startOfDay(for: first)
            let end = calendar.dateInterval(of: component, for: now)?.end ?? now
            return DateInterval(start: start, end: max(end, start))
        }
    }

    func bucketComponent(for range: StatsRange, earliest: Date?) -> Calendar.Component {
        switch range {
        case .day: return .hour
        case .week, .month: return .day
        case .year: return .month
        case .all: return allTimeBucketComponent(earliest: earliest)
        }
    }

    /// Monthly bars for up to three years of history, yearly bars beyond that.
    private func allTimeBucketComponent(earliest: Date?) -> Calendar.Component {
        guard let earliest else { return .month }
        let months = calendar.dateComponents([.month], from: earliest, to: now).month ?? 0
        return months > 36 ? .year : .month
    }

    private func shiftedInterval(_ component: Calendar.Component, offset: Int) -> DateInterval {
        let anchor = calendar.date(byAdding: component, value: offset, to: now) ?? now
        return calendar.dateInterval(of: component, for: anchor) ?? DateInterval(start: anchor, duration: 0)
    }

    // MARK: Snapshot

    /// Aggregates `sessions` (which may include records from before the period that
    /// spill into it) into a snapshot. `previousSessions` covers the preceding period
    /// for the comparison figure.
    func snapshot(
        range: StatsRange,
        offset: Int,
        earliest: Date?,
        sessions: [StatsSessionItem],
        previousSessions: [StatsSessionItem]?,
        focusDays: Set<Date>
    ) -> StatsSnapshot {
        let period = interval(for: range, offset: offset, earliest: earliest)
        let component = bucketComponent(for: range, earliest: earliest)
        var buckets = makeBuckets(in: period, component: component)

        var hourly = Array(repeating: 0, count: 24)
        var weekday = Array(repeating: 0, count: 7)
        var dailyFocus: [Date: Int] = [:]
        var workSeconds = 0
        var stopwatchSeconds = 0
        var breakSeconds = 0
        var focusCount = 0
        var breakCount = 0
        var longest = 0
        var items: [StatsSessionItem] = []

        for session in sessions {
            let type = session.type

            // Count and list sessions by the period they started in.
            if session.date >= period.start && session.date < period.end {
                items.append(session)
                if type == .shortBreak {
                    breakCount += 1
                } else {
                    focusCount += 1
                    longest = max(longest, session.duration)
                }
                if let bucket = bucketIndex(for: session.date, in: buckets) {
                    buckets[bucket].sessions += type == .shortBreak ? 0 : 1
                }
            }

            // Attribute time hour by hour so long sessions spread across the hours,
            // days and months they actually covered.
            for piece in hourPieces(of: session) where piece.start >= period.start && piece.start < period.end {
                switch type {
                case .work: workSeconds += piece.seconds
                case .stopwatch: stopwatchSeconds += piece.seconds
                case .shortBreak: breakSeconds += piece.seconds
                }

                if let bucket = bucketIndex(for: piece.start, in: buckets) {
                    switch type {
                    case .work: buckets[bucket].workSeconds += piece.seconds
                    case .stopwatch: buckets[bucket].stopwatchSeconds += piece.seconds
                    case .shortBreak: buckets[bucket].breakSeconds += piece.seconds
                    }
                }

                guard type != .shortBreak else { continue }
                hourly[calendar.component(.hour, from: piece.start)] += piece.seconds
                weekday[(calendar.component(.weekday, from: piece.start) + 5) % 7] += piece.seconds
                dailyFocus[calendar.startOfDay(for: piece.start), default: 0] += piece.seconds
            }
        }

        let best = dailyFocus.max { $0.value < $1.value }
        let streakCounts = streaks(focusDays: focusDays)

        var previousFocus: Int?
        if let previousSessions, range.supportsNavigation {
            let previousPeriod = interval(for: range, offset: offset - 1, earliest: earliest)
            var total = 0
            for session in previousSessions where session.isFocus {
                for piece in hourPieces(of: session) where piece.start >= previousPeriod.start && piece.start < previousPeriod.end {
                    total += piece.seconds
                }
            }
            previousFocus = total
        }

        return StatsSnapshot(
            range: range,
            interval: period,
            bucketComponent: component,
            buckets: buckets,
            hourly: hourly,
            weekday: weekday,
            workSeconds: workSeconds,
            stopwatchSeconds: stopwatchSeconds,
            breakSeconds: breakSeconds,
            focusSessionCount: focusCount,
            breakSessionCount: breakCount,
            longestSessionSeconds: longest,
            elapsedDays: elapsedDays(in: period, from: range == .all ? earliest : nil),
            activeDays: dailyFocus.values.filter { $0 > 0 }.count,
            bestDay: best.map { (date: $0.key, seconds: $0.value) },
            previousFocusSeconds: previousFocus,
            currentStreak: streakCounts.current,
            longestStreak: streakCounts.longest,
            sessions: items
        )
    }

    // MARK: Streaks

    /// Current streak counts back from today (or yesterday, if today has no session yet).
    func streaks(focusDays: Set<Date>) -> (current: Int, longest: Int) {
        guard !focusDays.isEmpty else { return (0, 0) }

        let today = calendar.startOfDay(for: now)
        var expected = focusDays.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)
        var current = 0
        while focusDays.contains(expected) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: expected) else { break }
            expected = previous
        }

        var longest = 0
        var run = 0
        var previousDay: Date?
        for day in focusDays.sorted() {
            if let previousDay,
               let next = calendar.date(byAdding: .day, value: 1, to: previousDay),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previousDay = day
        }

        return (current, longest)
    }

    // MARK: Helpers

    private func makeBuckets(in period: DateInterval, component: Calendar.Component) -> [StatsBucket] {
        var buckets: [StatsBucket] = []
        var cursor = period.start
        while cursor < period.end, buckets.count < 1000 {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            let interval = DateInterval(start: cursor, end: min(next, period.end))
            buckets.append(StatsBucket(
                id: buckets.count,
                interval: interval,
                isCurrent: interval.contains(now) && now < interval.end,
                isFuture: interval.start > now
            ))
            cursor = next
        }
        return buckets
    }

    /// Buckets are contiguous and sorted, so a binary search finds the owner.
    private func bucketIndex(for date: Date, in buckets: [StatsBucket]) -> Int? {
        var low = 0
        var high = buckets.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let interval = buckets[mid].interval
            if date < interval.start {
                high = mid - 1
            } else if date >= interval.end {
                low = mid + 1
            } else {
                return mid
            }
        }
        return nil
    }

    /// Splits a session into chunks that each stay inside one clock hour.
    private func hourPieces(of session: StatsSessionItem) -> [(start: Date, seconds: Int)] {
        var pieces: [(start: Date, seconds: Int)] = []
        var cursor = session.date
        var remaining = session.duration
        while remaining > 0 {
            let hourEnd = calendar.dateInterval(of: .hour, for: cursor)?.end ?? cursor.addingTimeInterval(3600)
            let chunk = min(remaining, max(1, Int(hourEnd.timeIntervalSince(cursor).rounded(.up))))
            pieces.append((cursor, chunk))
            remaining -= chunk
            cursor = cursor.addingTimeInterval(TimeInterval(chunk))
        }
        return pieces
    }

    /// Days of the period that have already begun (at least 1), so averages for the
    /// current period are not diluted by days that have not happened yet.
    /// `from` narrows the start, e.g. to the first recorded session for "All".
    private func elapsedDays(in period: DateInterval, from: Date? = nil) -> Int {
        let start = max(period.start, from.map { calendar.startOfDay(for: $0) } ?? period.start)
        let end = min(period.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now)
        guard end > start else { return 0 }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days, 1)
    }
}
