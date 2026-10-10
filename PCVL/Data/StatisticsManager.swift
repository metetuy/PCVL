import Foundation
import SwiftData
import Combine
import AppKit

// MARK: - Session Type

enum SessionType: String, Codable {
    case work
    case shortBreak = "break"
    case stopwatch

    /// Everything but a break counts as focus time (and can belong to a task).
    var isFocus: Bool { self != .shortBreak }
}

// MARK: - Session Record

@Model
class SessionRecord {
    var duration: Int
    var date: Date
    var type: String
    /// The task this focus session counted toward; nil for breaks and untagged sessions.
    var task: FocusTask?

    init(duration: Int, date: Date, type: SessionType) {
        self.duration = duration
        self.date = date
        self.type = type.rawValue
    }

    var sessionType: SessionType {
        SessionType(rawValue: type) ?? .work
    }

    /// Value copy for aggregation and lists.
    var item: StatsSessionItem {
        StatsSessionItem(id: persistentModelID, date: date, duration: duration, type: sessionType, taskID: task?.id)
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
        let schema = Schema([SessionRecord.self, FocusTask.self])
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
            // One by one, not a batch delete: a batch bypasses the context, so tasks
            // already loaded would keep listing the deleted sessions.
            for session in allSessions() {
                modelContext.delete(session)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete all sessions: \(error)")
        }
        focusDayCache = nil
        didChange.send()
    }

    /// Records a session; focus sessions are linked to `taskID` when it names a task.
    func recordSession(duration: Int, date: Date, type: SessionType, taskID: UUID? = nil) {
        let record = SessionRecord(duration: duration, date: date, type: type)
        modelContext.insert(record)
        if type.isFocus, let taskID {
            record.task = modelContext.focusTask(id: taskID)
        }
        try? modelContext.save()
        if type.isFocus {
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
        .map(\.item)
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

// MARK: - Tasks

extension StatisticsManager {
    /// Every focus session with its task, for all-time task totals. Unlike the
    /// period snapshots nothing is split by hour or day: a task's time is simply
    /// the sum of its sessions.
    func focusSessionItems() -> [StatsSessionItem] {
        let shortBreak = SessionType.shortBreak.rawValue
        let descriptor = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.type != shortBreak },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return sessions.map(\.item)
    }

    /// Links one focus session to a task, or with nil removes its task.
    func assignSession(_ id: PersistentIdentifier, toTask taskID: UUID?) {
        guard let session: SessionRecord = modelContext.registeredModel(for: id),
              session.sessionType.isFocus else { return }
        session.task = taskID.flatMap { modelContext.focusTask(id: $0) }
        try? modelContext.save()
        didChange.send()
    }

    /// Links every focus session that has no task yet (e.g. recorded before tasks
    /// existed) to a task. Returns how many were assigned.
    @discardableResult
    func assignUntaggedSessions(toTask taskID: UUID) -> Int {
        guard let task = modelContext.focusTask(id: taskID) else { return 0 }
        let shortBreak = SessionType.shortBreak.rawValue
        let descriptor = FetchDescriptor<SessionRecord>(predicate: #Predicate { $0.type != shortBreak })
        let untagged = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.task == nil }
        guard !untagged.isEmpty else { return 0 }
        for session in untagged {
            session.task = task
        }
        try? modelContext.save()
        didChange.send()
        return untagged.count
    }
}

// MARK: - Export

extension StatisticsManager {
    /// One exported session: `{ duration, type, created_at, task? }` with an ISO8601
    /// timestamp, so the file can be re-imported or processed elsewhere.
    private struct ExportedSession: Encodable {
        let duration: Int
        let type: String
        let createdAt: String
        let task: String?

        enum CodingKeys: String, CodingKey {
            case duration, type, task
            case createdAt = "created_at"
        }
    }

    /// Every recorded session, newest first, as pretty-printed JSON.
    func exportedSessionsJSON() throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sessions = allSessions().map {
            ExportedSession(
                duration: $0.duration,
                type: $0.type,
                createdAt: formatter.string(from: $0.date),
                task: $0.task?.title
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(sessions)
    }
}
