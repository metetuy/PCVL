import Foundation
import Testing
@testable import PCVL

/// Aggregation against a fixed clock and UTC calendar.
struct StatsAnalyzerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Wednesday, Oct 7 2026, 15:30 UTC.
    private var now: Date { date(7, 15, 30) }
    private var analyzer: StatsAnalyzer { StatsAnalyzer(now: now, calendar: calendar) }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func session(_ start: Date, minutes: Int, _ type: SessionType = .work, id: Int = 0) -> StatsSessionItem {
        StatsSessionItem(id: id, date: start, duration: minutes * 60, type: type)
    }

    private func snapshot(_ range: StatsRange, _ sessions: [StatsSessionItem], focusDays: Set<Date> = []) -> StatsSnapshot {
        analyzer.snapshot(range: range, offset: 0, earliest: sessions.map(\.date).min(),
                          sessions: sessions, previousSessions: sessions, focusDays: focusDays)
    }

    @Test func sessionsAreSplitAtHourBoundaries() {
        let snap = snapshot(.day, [session(date(7, 13, 40), minutes: 50)])
        #expect(snap.hourly[13] == 20 * 60)
        #expect(snap.hourly[14] == 30 * 60)
        #expect(snap.buckets[13].focusSeconds == 20 * 60)
        #expect(snap.buckets[14].focusSeconds == 30 * 60)
        #expect(snap.buckets[13].sessions == 1, "a session counts in the bucket it started in")
        #expect(snap.peakHour == 14)
    }

    @Test func overnightSessionOnlyCountsTheTimeInsideThePeriod() {
        let snap = snapshot(.day, [session(date(6, 23, 30), minutes: 60)])
        #expect(snap.focusSeconds == 30 * 60)
        #expect(snap.sessions.isEmpty, "listed under the day it started")
        #expect(snap.focusSessionCount == 0)
    }

    @Test func weeksRunMondayToSunday() {
        let snap = snapshot(.week, [session(date(11, 10), minutes: 30)]) // Sunday
        #expect(snap.buckets.count == 7)
        #expect(snap.buckets.first?.interval.start == date(5, 0))
        #expect(snap.buckets.firstIndex { $0.isCurrent } == 2)
        #expect(snap.buckets.filter(\.isFuture).count == 4)
        #expect(snap.weekday[6] == 30 * 60)
        #expect(snap.peakWeekday == 6)
    }

    @Test func breaksAreTrackedButNotFocus() {
        let snap = snapshot(.day, [
            session(date(7, 9), minutes: 25, .work, id: 0),
            session(date(7, 9, 30), minutes: 5, .shortBreak, id: 1),
            session(date(7, 11), minutes: 15, .stopwatch, id: 2)
        ])
        #expect(snap.focusSeconds == 40 * 60)
        #expect(snap.breakSeconds == 5 * 60)
        #expect(snap.focusSessionCount == 2)
        #expect(snap.breakSessionCount == 1)
        #expect(snap.longestSessionSeconds == 25 * 60)
        #expect(snap.hourly.reduce(0, +) == 40 * 60)
        #expect(snap.focusShare == 40.0 / 45.0)
    }

    @Test func changeIsMeasuredAgainstThePreviousPeriod() {
        let snap = snapshot(.week, [
            session(date(29, 10, month: 9), minutes: 60, id: 0), // last week
            session(date(6, 10), minutes: 90, id: 1)
        ])
        #expect(snap.previousFocusSeconds == 3600)
        #expect(snap.changeRatio == 0.5)
    }

    @Test func dailyAverageOnlyCountsDaysThatHaveStarted() {
        let snap = snapshot(.week, [session(date(5, 10), minutes: 90)])
        #expect(snap.elapsedDays == 3) // Mon–Wed
        #expect(snap.dailyAverageSeconds == 30 * 60)
    }

    @Test func streaks() {
        let days: Set<Date> = Set([0, 1, 2, 5, 6, 7, 8].map { calendar.date(byAdding: .day, value: -$0, to: date(7, 0))! })
        let result = analyzer.streaks(focusDays: days)
        #expect(result.current == 3)
        #expect(result.longest == 4)
    }

    @Test func streakStillCountsBeforeTodaysFirstSession() {
        let days: Set<Date> = [date(6, 0), date(5, 0)]
        #expect(analyzer.streaks(focusDays: days).current == 2)
        #expect(analyzer.streaks(focusDays: [date(4, 0)]).current == 0)
    }

    @Test func allTimeSwitchesToYearlyBarsAfterThreeYears() {
        #expect(analyzer.bucketComponent(for: .all, earliest: date(1, 0, month: 1)) == .month)
        let old = calendar.date(byAdding: .year, value: -4, to: now)!
        #expect(analyzer.bucketComponent(for: .all, earliest: old) == .year)
    }
}
