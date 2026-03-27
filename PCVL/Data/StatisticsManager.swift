import Foundation
import SwiftData
import Combine

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

    func workSessions() -> [SessionRecord] {
        allSessions().filter { $0.sessionType == .work }
    }

    func focusSessions() -> [SessionRecord] {
        allSessions().filter { $0.sessionType == .work || $0.sessionType == .stopwatch }
    }

    // MARK: - Today

    func todaySessions() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return focusSessions().filter { $0.date >= today }.count
    }

    func todayFocusMinutes() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let totalSeconds = focusSessions()
            .filter { $0.date >= today }
            .reduce(0) { $0 + $1.duration }
        return totalSeconds / 60
    }

    // MARK: - Totals

    func totalSessionsCompleted() -> Int {
        focusSessions().count
    }

    func totalFocusHours() -> Double {
        let totalSeconds = focusSessions().reduce(0) { $0 + $1.duration }
        return Double(totalSeconds) / 3600.0
    }

    // MARK: - Streak

    func currentStreak() -> Int {
        let calendar = Calendar.current
        let sessions = focusSessions()
        guard !sessions.isEmpty else { return 0 }

        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = sessionDays.sorted(by: >)

        var streak = 0
        var expectedDay = calendar.startOfDay(for: Date())

        if !sortedDays.contains(expectedDay) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: expectedDay) else {
                return 0
            }
            expectedDay = yesterday
        }

        for day in sortedDays {
            if day == expectedDay {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: expectedDay) else { break }
                expectedDay = previousDay
            } else if day < expectedDay {
                break
            }
        }

        return streak
    }

    // MARK: - Weekly Data

    /// Returns focus minutes for each day of the current week (Mon–Sun)
    func weeklyData() -> [(day: String, minutes: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        // Find Monday of this week
        let weekday = calendar.component(.weekday, from: today)
        // Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart) else {
            return []
        }

        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let sessions = focusSessions()

        return (0..<7).map { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: monday),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return (day: dayNames[offset], minutes: 0, isToday: false)
            }

            let dayMinutes = sessions
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .reduce(0) { $0 + $1.duration } / 60

            let isTodayDay = calendar.isDate(dayStart, inSameDayAs: today)
            return (day: dayNames[offset], minutes: dayMinutes, isToday: isTodayDay)
        }
    }

    // MARK: - Recent Sessions

    func recentSessions(limit: Int = 20) -> [SessionRecord] {
        Array(allSessions().prefix(limit))
    }
}
