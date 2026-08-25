import Foundation
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

struct SessionRecord: Identifiable {
    let id: Int
    var duration: Int
    var date: Date
    var type: String

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
    @Published private(set) var sessions: [SessionRecord] = []

    private let apiClient: SessionAPIClient

    init(apiClient: SessionAPIClient = SessionAPIClient()) {
        self.apiClient = apiClient
        Task { await refresh() }
    }

    // MARK: - Sync

    func refresh() async {
        do {
            let remoteSessions = try await apiClient.fetchSessions()
            sessions = remoteSessions
                .map { SessionRecord(id: $0.id, duration: $0.duration, date: $0.createdAt, type: $0.type) }
                .sorted { $0.date > $1.date }
        } catch {
            print("Failed to refresh sessions from backend: \(error)")
        }
    }

    // MARK: - Record

    func deleteAllSessions() {
        Task {
            do {
                try await apiClient.deleteAllSessions()
                await refresh()
            } catch {
                print("Failed to delete all sessions: \(error)")
            }
        }
    }

    func recordSession(duration: Int, date: Date, type: SessionType) {
        Task {
            do {
                _ = try await apiClient.createSession(duration: duration, type: type.rawValue)
                await refresh()
            } catch {
                print("Failed to record session to backend: \(error)")
            }
        }
    }

    // MARK: - Queries

    func allSessions() -> [SessionRecord] {
        sessions
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

// MARK: - TEMPORARY: One-time migration export
// TODO: Delete this extension after the historical data migration to the new backend is complete.

extension StatisticsManager {
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
