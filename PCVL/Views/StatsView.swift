import SwiftUI

// MARK: - Stats View

/// Concise stats for the menu bar panel: today, this week, and the latest sessions.
/// The full analytics live in the window (AnalyticsScreen).
struct StatsView: View {
    @ObservedObject var viewModel: StatsSummaryViewModel
    @ObservedObject var theme: ThemeManager

    @AppStorage(StatsTimeUnit.storageKey) private var unitRaw = StatsTimeUnit.minutes.rawValue
    @State private var hoveredBucketID: Int?

    private var unit: StatsTimeUnit { StatsTimeUnit(rawValue: unitRaw) ?? .minutes }
    private var week: StatsSnapshot { viewModel.week }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                todayRow
                weekCard
                recentCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            // Leaves room for the panel's expand handle.
            .padding(.bottom, 24)
        }
        .onAppear { viewModel.refresh() }
    }

    // MARK: - Today

    private var todayRow: some View {
        HStack(spacing: 8) {
            StatCard(value: unit.format(viewModel.todayFocusSeconds), label: "Today", theme: theme)
            StatCard(value: "\(viewModel.todaySessions)", label: "Sessions", theme: theme)
            StatCard(value: "\(viewModel.streak)d", label: "Streak", valueColor: theme.colors.accent, theme: theme, flameLit: viewModel.streak > 0)
        }
    }

    // MARK: - This Week

    private var hoveredBucket: StatsBucket? {
        hoveredBucketID.flatMap { id in week.buckets.first { $0.id == id } }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let bucket = hoveredBucket {
                    SectionHeader(title: viewModel.bucketTitle(bucket), theme: theme)
                    Spacer()
                    valueText(unit.format(bucket.focusSeconds))
                    secondaryText("· \(bucket.sessions) sessions")
                } else {
                    SectionHeader(title: "This week", theme: theme)
                    Spacer()
                    valueText(unit.format(week.focusSeconds))
                    if let change = viewModel.changeText {
                        secondaryText(change)
                            .foregroundColor(viewModel.changeIsPositive ? theme.colors.accent : theme.colors.textSecondary)
                    }
                }
            }
            .lineLimit(1)

            FocusBarChart(
                buckets: week.buckets,
                component: .day,
                unit: unit,
                averageSeconds: 0,
                axisLabel: viewModel.axisLabel(for:),
                hoveredID: $hoveredBucketID,
                theme: theme
            )
            .frame(height: 56)
        }
        .padding(10)
        .cardBackground(theme)
    }

    // MARK: - Recent

    private var recentCard: some View {
        let sessions = Array(week.sessions.prefix(4))

        return VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Recent", theme: theme)

            if sessions.isEmpty {
                secondaryText("No sessions this week")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        SessionRow(session: session, theme: theme)
                        if index < sessions.count - 1 {
                            Divider().background(theme.colors.ringTrack)
                        }
                    }
                }
            }
        }
        .padding(10)
        .cardBackground(theme)
    }

    // MARK: - Helpers

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 9, weight: .bold))
            .foregroundColor(theme.colors.text)
    }

    private func secondaryText(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 8, weight: .medium))
            .foregroundColor(theme.colors.textSecondary)
    }
}
