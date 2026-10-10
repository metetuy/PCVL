import Foundation
import SwiftData
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Session Type

enum SessionType: String, Codable {
    case work
    case shortBreak = "break"
    case stopwatch
}

// MARK: - Session Record

@Model
class SessionRecord {
    var duration: Int
    var date: Date
    var type: String

    init(duration: Int, date: Date, type: SessionType) {
        self.duration = duration
        self.date = date
        self.type = type.rawValue
    }

    var sessionType: SessionType {
        SessionType(rawValue: type) ?? .work
    }

    var durationFormatted: String {
        let m = duration / 60
        let s = duration % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }
}

// MARK: - Statistics Manager

@MainActor
class StatisticsManager: ObservableObject {
    let modelContainer: ModelContainer
    private var modelContext: ModelContext

    init() {
        let schema = Schema([SessionRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Record

    func deleteAllSessions() {
        do {
            try modelContext.delete(model: SessionRecord.self)
            try modelContext.save()
            objectWillChange.send()
        } catch {
            print("Failed to delete all sessions: \(error)")
        }
    }

    func recordSession(duration: Int, date: Date, type: SessionType) {
        let record = SessionRecord(duration: duration, date: date, type: type)
        modelContext.insert(record)
        try? modelContext.save()
        objectWillChange.send()
    }

    // MARK: - Queries

    func allSessions() -> [SessionRecord] {
        let descriptor = FetchDescriptor<SessionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Sessions that started inside `[start, end)`, newest first. Uses a store
    /// predicate so only the requested window is loaded.
    func sessions(from start: Date, to end: Date) -> [SessionRecord] {
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Start date of the oldest recorded session, if any.
    func firstSessionDate() -> Date? {
        var descriptor = FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.date
    }

    /// Distinct calendar days (start of day) with at least one focus session.
    /// Used for streak calculations.
    func focusDays(calendar: Calendar = .current) -> Set<Date> {
        let work = SessionType.work.rawValue
        let stopwatch = SessionType.stopwatch.rawValue
        var descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.type == work || $0.type == stopwatch }
        )
        descriptor.propertiesToFetch = [\.date]
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return Set(sessions.map { calendar.startOfDay(for: $0.date) })
    }

    // MARK: - Today

    /// Focus seconds and focus session count for today.
    func todayFocusSummary() -> (seconds: Int, sessions: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return (0, 0) }
        let focus = sessions(from: today, to: tomorrow).filter { $0.sessionType != .shortBreak }
        return (focus.reduce(0) { $0 + $1.duration }, focus.count)
    }

    // MARK: - Streak

    func currentStreak() -> Int {
        StatsAnalyzer().streaks(focusDays: focusDays()).current
    }

    // MARK: - Snapshot

    /// Fetches only what the period (and the previous one, for comparison) needs and
    /// aggregates it. `offset` 0 is the current period, -1 the one before, and so on.
    func snapshot(range: StatsRange, offset: Int = 0) -> StatsSnapshot {
        let analyzer = StatsAnalyzer()
        let earliest = firstSessionDate()
        let period = analyzer.interval(for: range, offset: offset, earliest: earliest)
        let fetchStart = range.supportsNavigation
            ? analyzer.interval(for: range, offset: offset - 1, earliest: earliest).start
            : period.start
        let records = sessions(
            from: fetchStart.addingTimeInterval(-StatsAnalyzer.spilloverLookback),
            to: period.end
        )
        return analyzer.snapshot(
            range: range,
            offset: offset,
            earliest: earliest,
            sessions: records,
            previousSessions: range.supportsNavigation ? records : nil,
            focusDays: focusDays()
        )
    }
}

// MARK: - Export

extension StatisticsManager {
    /// Writes all recorded sessions to a user-chosen JSON file. Each entry is
    /// `{ duration, type, created_at }` with an ISO8601 timestamp, so the file
    /// can be re-imported or processed elsewhere.
    func exportSessionsToJSON() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "sessions_export.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessions = allSessions().map { session in
            [
                "duration": session.duration,
                "type": session.type,
                "created_at": formatter.string(from: session.date)
            ] as [String: Any]
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: sessions, options: [.prettyPrinted])
            try data.write(to: url)
            print("Exported \(sessions.count) sessions to \(url.path)")
        } catch {
            print("Failed to export sessions: \(error)")
        }
    }
}
