import Foundation
import Testing
@testable import PCVL

/// The view models that derive from the store, against an in-memory store.
@MainActor
struct StatsSummaryTests {
    private let stats = StatisticsManager(inMemory: true)
    private let settings: AppSettings

    init() {
        settings = AppSettings(statsManager: stats, updater: Updater(defaults: UserDefaults(suiteName: "PCVLTests.StatsSummary")!), defaults: UserDefaults(suiteName: "PCVLTests.StatsSummary")!)
    }

    /// An hour into today, so the session never straddles midnight.
    private var todayAtOne: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(3600)
    }

    @Test func todayAndStreakUpdateAsSessionsAreRecorded() {
        let summary = StatsSummaryViewModel(statsManager: stats, settings: settings)
        #expect(summary.todayFocusSeconds == 0)
        #expect(summary.streak == 0)

        stats.recordSession(duration: 600, date: todayAtOne, type: .work)
        stats.recordSession(duration: 300, date: todayAtOne.addingTimeInterval(700), type: .shortBreak)

        #expect(summary.todayFocusSeconds == 600)
        #expect(summary.todaySessions == 1, "breaks are not focus sessions")
        #expect(summary.streak == 1)
        #expect(summary.todaySummaryText(inProgressSeconds: 120) == "Today 12m · 1 session · 1-day streak")
    }

    @Test func overnightSessionCountsOnlyTodaysPart() {
        let midnight = Calendar.current.startOfDay(for: Date())
        stats.recordSession(duration: 3600, date: midnight.addingTimeInterval(-1800), type: .work)
        let summary = StatsSummaryViewModel(statsManager: stats, settings: settings)
        #expect(summary.todayFocusSeconds == 1800)
    }

    @Test func focusDaysFollowInsertsAndDeletes() {
        #expect(stats.focusDays().isEmpty)
        stats.recordSession(duration: 60, date: todayAtOne, type: .shortBreak)
        #expect(stats.focusDays().isEmpty, "breaks do not start a streak")
        stats.recordSession(duration: 60, date: todayAtOne, type: .stopwatch)
        #expect(stats.focusDays() == [Calendar.current.startOfDay(for: todayAtOne)])
        stats.deleteAllSessions()
        #expect(stats.focusDays().isEmpty)
    }

    @Test func analyticsOnlyRecomputesWhileActive() {
        let analytics = AnalyticsViewModel(statsManager: stats, settings: settings)
        stats.recordSession(duration: 600, date: todayAtOne, type: .work)
        #expect(analytics.snapshot.focusSeconds == 0, "inactive: the change is deferred")

        analytics.isActive = true
        #expect(analytics.snapshot.focusSeconds == 600)

        stats.recordSession(duration: 300, date: todayAtOne.addingTimeInterval(900), type: .work)
        #expect(analytics.snapshot.focusSeconds == 900, "active: applied right away")
    }

    @Test func unitIsSharedBetweenPanelAndWindow() {
        let summary = StatsSummaryViewModel(statsManager: stats, settings: settings)
        let analytics = AnalyticsViewModel(statsManager: stats, settings: settings)
        analytics.unit = .hours
        #expect(summary.unit == .hours)
        analytics.unit = .minutes
        #expect(summary.unit == .minutes)
    }

    @Test(arguments: [TimerViewModel.AdjustableDuration.work, .breakTime])
    func menuPresetsIncludeTheDefaultAndStayInBounds(duration: TimerViewModel.AdjustableDuration) {
        #expect(duration.menuPresets.contains(duration.defaultMinutes))
        #expect(duration.menuPresets.allSatisfy(duration.bounds.contains))
    }
}
