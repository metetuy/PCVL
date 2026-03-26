import Foundation
import SwiftData
import Combine

enum SessionType: String, Codable {
    case work
    case shortBreak = "break"
}

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

    func recordSession(duration: Int, date: Date, type: SessionType) {
        let record = SessionRecord(duration: duration, date: date, type: type)
        modelContext.insert(record)
        try? modelContext.save()
    }

    func allSessions() -> [SessionRecord] {
        let descriptor = FetchDescriptor<SessionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func workSessions() -> [SessionRecord] {
        allSessions().filter { $0.sessionType == .work }
    }

    func totalFocusTime() -> Int {
        workSessions().reduce(0) { $0 + $1.duration }
    }

    func totalSessionsCompleted() -> Int {
        workSessions().count
    }

    func todaySessions() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return workSessions().filter { $0.date >= today }.count
    }

    func todayFocusMinutes() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayDuration = workSessions()
            .filter { $0.date >= today }
            .reduce(0) { $0 + $1.duration }
        return todayDuration / 60
    }

    func currentStreak() -> Int {
        let calendar = Calendar.current
        let sessions = workSessions()
        guard !sessions.isEmpty else { return 0 }

        let sessionDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        let sortedDays = sessionDays.sorted(by: >)

        var streak = 0
        var expectedDay = calendar.startOfDay(for: Date())

        // If no session today, start checking from yesterday
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
}
