import Foundation
import SwiftData
import Combine
import AppKit

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
}

// MARK: - Statistics Manager

@MainActor
final class StatisticsManager {
    let modelContainer: ModelContainer
    private var modelContext: ModelContext

    /// Fires after the store changed, and when the calendar day rolls over (or the Mac
    /// wakes or the time zone changes), so "today" and streaks never go stale.
    /// Subscribers recompute whatever they derive from the store.
    let didChange = PassthroughSubject<Void, Never>()

    /// Start-of-day dates with at least one focus session, kept in sync with inserts
    /// and deletes so streaks never rescan the whole store. Nil until first needed.
    private var focusDayCache: Set<Date>?
    private var observers = Set<AnyCancellable>()

    /// `inMemory` keeps records out of the user's store (used by tests).
    init(inMemory: Bool = false) {
        let schema = Schema([SessionRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        observeClock()
    }

    private func observeClock() {
        let center = NotificationCenter.default
        Publishers.MergeMany(
            center.publisher(for: .NSCalendarDayChanged),
            center.publisher(for: .NSSystemTimeZoneDidChange),
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            // Day boundaries move with the time zone, so cached days are rebuilt.
            self?.focusDayCache = nil
            self?.didChange.send()
        }
        .store(in: &observers)
    }

    // MARK: - Record

    func deleteAllSessions() {
        do {
            try modelContext.delete(model: SessionRecord.self)
            try modelContext.save()
        } catch {
            print("Failed to delete all sessions: \(error)")
        }
        focusDayCache = nil
        didChange.send()
    }

    func recordSession(duration: Int, date: Date, type: SessionType) {
        modelContext.insert(SessionRecord(duration: duration, date: date, type: type))
        try? modelContext.save()
        if type != .shortBreak {
            focusDayCache?.insert(Calendar.current.startOfDay(for: date))
        }
        didChange.send()
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
    /// Used for streak calculations; scanned from the store once, then cached.
    func focusDays() -> Set<Date> {
        if let focusDayCache { return focusDayCache }
        let work = SessionType.work.rawValue
        let stopwatch = SessionType.stopwatch.rawValue
        var descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.type == work || $0.type == stopwatch }
        )
        descriptor.propertiesToFetch = [\.date]
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        focusDayCache = days
        return days
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
        .map { StatsSessionItem(id: $0.persistentModelID, date: $0.date, duration: $0.duration, type: $0.sessionType) }
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
    /// One exported session: `{ duration, type, created_at }` with an ISO8601
    /// timestamp, so the file can be re-imported or processed elsewhere.
    private struct ExportedSession: Encodable {
        let duration: Int
        let type: String
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case duration, type
            case createdAt = "created_at"
        }
    }

    /// Every recorded session, newest first, as pretty-printed JSON.
    func exportedSessionsJSON() throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sessions = allSessions().map {
            ExportedSession(duration: $0.duration, type: $0.type, createdAt: formatter.string(from: $0.date))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sessions)
    }
}
