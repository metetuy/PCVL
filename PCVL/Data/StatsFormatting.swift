import Foundation

// MARK: - Stats Formatting

/// Display strings for statistics, shared by the panel and the analytics window.
enum StatsFormat {
    static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

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

    // MARK: Periods

    static func periodTitle(for snapshot: StatsSnapshot, offset: Int) -> String {
        let interval = snapshot.interval
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: interval.start) == calendar.component(.year, from: Date())

        switch snapshot.range {
        case .day:
            if offset == 0 { return "Today" }
            if offset == -1 { return "Yesterday" }
            return interval.start.formatted(
                sameYear
                    ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
                    : .dateTime.month(.abbreviated).day().year()
            )
        case .week:
            if offset == 0 { return "This Week" }
            if offset == -1 { return "Last Week" }
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
            guard let first = snapshot.sessions.last?.date else { return "All Time" }
            return "Since \(first.formatted(.dateTime.month(.abbreviated).year()))"
        }
    }

    /// Detailed label for one bar, e.g. "14:00 – 15:00" or "Tue, Oct 7".
    static func bucketTitle(_ bucket: StatsBucket, component: Calendar.Component) -> String {
        let start = bucket.interval.start
        switch component {
        case .hour:
            return "\(timeFormatter.string(from: start)) – \(timeFormatter.string(from: bucket.interval.end))"
        case .day:
            return start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .month:
            return start.formatted(.dateTime.month(.wide).year())
        default:
            return start.formatted(.dateTime.year())
        }
    }

    /// Short x-axis label for a bar's start date.
    static func axisLabel(for date: Date, component: Calendar.Component, range: StatsRange) -> String {
        switch component {
        case .hour:
            return hourFormatter.string(from: date)
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

    static func chartTitle(for component: Calendar.Component) -> String {
        switch component {
        case .hour: return "FOCUS BY HOUR"
        case .day: return "FOCUS BY DAY"
        case .month: return "FOCUS BY MONTH"
        default: return "FOCUS BY YEAR"
        }
    }

    // MARK: Values

    static func changeText(_ ratio: Double?) -> String? {
        guard let ratio else { return nil }
        let percent = Int((ratio * 100).rounded())
        return "\(percent > 0 ? "+" : "")\(percent)%"
    }

    static func hourText(_ hour: Int?) -> String {
        guard let hour else { return "—" }
        return String(format: "%02d:00", hour)
    }

    static func hourRangeText(_ hour: Int) -> String {
        String(format: "%02d:00 – %02d:00", hour, (hour + 1) % 24)
    }

    static func weekdayText(_ index: Int?) -> String {
        guard let index else { return "—" }
        return weekdayNames[index]
    }

    static func percentText(_ share: Double?) -> String {
        guard let share else { return "—" }
        return "\(Int((share * 100).rounded()))%"
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Oct 3", with the year when it is not the current one ("Oct 3, 2025").
    static func dayText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            return shortDate(date)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: Sessions

    static func sessionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(shortDate(date)), \(time)"
    }

    /// A total in hours and minutes, e.g. "52h 10m" or "40m" — never rolls over into days.
    static func hoursMinutes(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "1 session" / "3 sessions".
    static func sessionCount(_ count: Int) -> String {
        "\(count) session\(count == 1 ? "" : "s")"
    }

    /// Exact session length, e.g. "1h 5m", "24m 10s" or "45s".
    static func sessionDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    static func typeLabel(_ type: SessionType) -> String {
        switch type {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .stopwatch: return "Free"
        }
    }
}
