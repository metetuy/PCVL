import SwiftUI

// MARK: - Analytics Screen

/// Detailed statistics for the window. Tasks first (all-time totals per task), then
/// time, raw data first: totals, the main chart with the session list beside it,
/// distributions, and derived insights at the bottom.
struct AnalyticsScreen: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @ObservedObject var tasks: TaskAnalyticsViewModel
    @ObservedObject var theme: ThemeManager
    let onShowTasks: () -> Void

    @State private var hoveredBucketID: Int?
    @State private var hoveredHour: Int?
    @State private var hoveredWeekday: Int?

    private let s: CGFloat = 1.2
    /// Content width above which the session list sits beside the main chart.
    private let wideWidth: CGFloat = 860
    private let sessionsWidth: CGFloat = 330

    private var snapshot: StatsSnapshot { viewModel.snapshot }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= wideWidth

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    TaskAnalyticsSection(viewModel: tasks, theme: theme, onShowTasks: onShowTasks)

                    Divider()
                        .background(theme.colors.ringTrack)
                        .padding(.vertical, 8)

                    header
                    kpiGrid(width: geo.size.width)

                    if wide {
                        // The chart sets the row height; the session list fills it and scrolls.
                        HStack(alignment: .top, spacing: 14) {
                            mainChartCard
                            Color.clear.frame(width: sessionsWidth)
                        }
                        .overlay(alignment: .topTrailing) {
                            sessionsCard
                                .frame(width: sessionsWidth)
                        }

                        HStack(alignment: .top, spacing: 14) {
                            hourlyCard
                            weekdayCard
                            BreakdownCard(snapshot: snapshot, unit: viewModel.unit, theme: theme, scale: s)
                                .frame(width: sessionsWidth)
                        }
                    } else {
                        mainChartCard
                        sessionsCard
                            .frame(height: 280)
                        HStack(alignment: .top, spacing: 14) {
                            hourlyCard
                            weekdayCard
                        }
                        BreakdownCard(snapshot: snapshot, unit: viewModel.unit, theme: theme, scale: s)
                    }

                    InsightsCard(snapshot: snapshot, unit: viewModel.unit, theme: theme, scale: s, columns: wide ? 5 : 3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 1500)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: snapshot.interval) { _, _ in
            hoveredBucketID = nil
            hoveredHour = nil
            hoveredWeekday = nil
        }
    }

    private var sessionsCard: some View {
        SessionsCard(
            sessions: snapshot.sessions,
            tasks: tasks.tasks,
            taskTitle: tasks.title(for:),
            menuTitle: tasks.menuTitle(for:),
            onAssign: tasks.assign(_:to:),
            theme: theme,
            scale: s
        )
    }

    // MARK: - Header

    /// Period on the left, range and unit controls on the right; the controls drop
    /// to a second row when the window is too narrow for one.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                periodNavigator
                Spacer(minLength: 12)
                headerControls
            }
            VStack(alignment: .leading, spacing: 10) {
                periodNavigator
                headerControls
            }
        }
    }

    private var periodNavigator: some View {
        HStack(spacing: 10) {
            navButton(icon: "chevron.left", enabled: viewModel.canGoBack, action: viewModel.goBack)
                .help("Previous period")

            Button(action: viewModel.goToCurrent) {
                Text(viewModel.periodTitle)
                    .font(theme.currentFont.font(size: 20, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help(viewModel.isCurrentPeriod ? "" : "Back to the current period")

            navButton(icon: "chevron.right", enabled: viewModel.canGoForward, action: viewModel.goForward)
                .help("Next period")

            if let change = viewModel.changeText {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.changeIsPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(theme.currentFont.font(size: 9, weight: .bold))
                        .foregroundColor(viewModel.changeIsPositive ? theme.colors.accent : theme.colors.textSecondary)
                    Text(change)
                        .font(theme.currentFont.font(size: 11, weight: .semibold))
                        .foregroundColor(theme.colors.text)
                    Text(snapshot.range.previousLabel)
                        .font(theme.currentFont.font(size: 10))
                        .foregroundColor(theme.colors.textSecondary)
                }
                .lineLimit(1)
                .padding(.leading, 6)
            }
        }
        .fixedSize()
    }

    private var headerControls: some View {
        HStack(spacing: 10) {
            CapsuleSegmentedControl(
                options: StatsRange.allCases,
                selection: $viewModel.range,
                title: \.label,
                theme: theme,
                scale: s
            )

            CapsuleSegmentedControl(
                options: StatsTimeUnit.allCases,
                selection: $viewModel.unit,
                title: { $0 == .minutes ? "Minutes" : "Hours" },
                theme: theme,
                scale: s
            )
            .help("Show time in minutes or hours")
        }
        .fixedSize()
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 10, weight: .bold))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(theme.colors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .hoverEffect()
    }

    // MARK: - KPIs

    /// Six cards in one row when there is room, otherwise wrapped into rows of three to five.
    private func kpiGrid(width: CGFloat) -> some View {
        let unit = viewModel.unit
        let columns = min(6, max(3, Int(width / 150)))
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            StatCard(value: unit.format(snapshot.focusSeconds), label: "Total focus", theme: theme, scale: s)
            StatCard(value: "\(snapshot.focusSessionCount)", label: "Sessions", theme: theme, scale: s)
            StatCard(value: unit.format(snapshot.dailyAverageSeconds), label: "Daily average", theme: theme, scale: s)
            StatCard(value: unit.format(snapshot.averageSessionSeconds), label: "Avg session", theme: theme, scale: s)
            StatCard(value: "\(snapshot.activeDays)/\(snapshot.elapsedDays)", label: "Active days", theme: theme, scale: s)
            StatCard(value: "\(snapshot.currentStreak)d", label: "Streak", valueColor: theme.colors.accent, theme: theme, scale: s, flameLit: snapshot.currentStreak > 0)
        }
    }

    // MARK: - Charts

    private var hoveredBucket: StatsBucket? {
        hoveredBucketID.flatMap { id in snapshot.buckets.first { $0.id == id } }
    }

    private var mainChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let bucket = hoveredBucket {
                    SectionHeader(title: viewModel.bucketTitle(bucket), theme: theme, scale: s)
                    Spacer()
                    valueText(viewModel.format(bucket.focusSeconds))
                    secondaryText("· \(bucket.sessions) sessions")
                } else {
                    SectionHeader(title: StatsFormat.chartTitle(for: snapshot.bucketComponent), theme: theme, scale: s)
                    Spacer()
                    if snapshot.bucketAverageSeconds > 0 {
                        secondaryText("avg \(viewModel.format(snapshot.bucketAverageSeconds))")
                    }
                }
            }
            .lineLimit(1)

            FocusBarChart(
                buckets: snapshot.buckets,
                component: snapshot.bucketComponent,
                unit: viewModel.unit,
                averageSeconds: snapshot.bucketAverageSeconds,
                maxAxisLabels: 16,
                axisLabel: viewModel.axisLabel(for:),
                hoveredID: $hoveredBucketID,
                theme: theme,
                scale: s
            )
            .frame(height: 260)
            .overlay {
                if snapshot.focusSeconds == 0 {
                    secondaryText("No focus time in this period")
                }
            }
        }
        .padding(14)
        .cardBackground(theme, radius: 10)
    }

    private var hourlyCard: some View {
        distributionCard(
            title: hoveredHour.map { StatsFormat.hourRangeText($0) } ?? "Time of day",
            detail: hoveredHour.map { viewModel.format(snapshot.hourly[$0]) }
                ?? snapshot.peakHour.map { "peak \(StatsFormat.hourText($0))" },
            chart: DistributionBarChart(
                values: snapshot.hourly,
                labels: (0..<24).map { String(format: "%02d", $0) },
                labeledIndices: [0, 6, 12, 18],
                unit: viewModel.unit,
                peakIndex: snapshot.peakHour,
                hoveredIndex: $hoveredHour,
                theme: theme,
                scale: s
            )
        )
    }

    private var weekdayCard: some View {
        distributionCard(
            title: hoveredWeekday.map { StatsFormat.weekdayNames[$0] } ?? "By weekday",
            detail: hoveredWeekday.map { viewModel.format(snapshot.weekday[$0]) }
                ?? snapshot.peakWeekday.map { "best \(StatsFormat.weekdayText($0))" },
            chart: DistributionBarChart(
                values: snapshot.weekday,
                labels: StatsFormat.weekdayNames,
                labeledIndices: Array(0..<7),
                unit: viewModel.unit,
                peakIndex: snapshot.peakWeekday,
                hoveredIndex: $hoveredWeekday,
                theme: theme,
                scale: s
            )
        )
    }

    private func distributionCard(title: String, detail: String?, chart: DistributionBarChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: title, theme: theme, scale: s)
                Spacer()
                if let detail {
                    secondaryText(detail)
                }
            }

            chart
                .frame(height: 130)
                .overlay {
                    if snapshot.focusSeconds == 0 {
                        secondaryText("No data")
                    }
                }
        }
        .padding(14)
        .cardBackground(theme, radius: 10)
    }

    // MARK: - Helpers

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 11, weight: .bold))
            .foregroundColor(theme.colors.text)
    }

    private func secondaryText(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 10, weight: .medium))
            .foregroundColor(theme.colors.textSecondary)
    }
}

// MARK: - Insights Card

private struct InsightsCard: View {
    let snapshot: StatsSnapshot
    let unit: StatsTimeUnit
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var columns: Int = 2

    var body: some View {
        let items: [(label: String, value: String)] = [
            ("Daily avg", unit.format(snapshot.dailyAverageSeconds)),
            ("Avg session", unit.format(snapshot.averageSessionSeconds)),
            ("Longest", unit.format(snapshot.longestSessionSeconds)),
            ("Best day", snapshot.bestDay.map { unit.format($0.seconds) } ?? "—"),
            ("Active days", "\(snapshot.activeDays)/\(snapshot.elapsedDays)"),
            ("Peak hour", StatsFormat.hourText(snapshot.peakHour)),
            ("Best weekday", StatsFormat.weekdayText(snapshot.peakWeekday)),
            ("Best streak", "\(snapshot.longestStreak)d"),
            ("Focus share", StatsFormat.percentText(snapshot.focusShare))
        ]
        let grid = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .leading), count: columns)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Insights", theme: theme, scale: scale)
                Spacer()
                if let best = snapshot.bestDay {
                    Text("best day \(StatsFormat.shortDate(best.date))")
                        .font(theme.currentFont.font(size: 8 * scale, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }

            LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
                ForEach(items, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.value)
                            .font(theme.currentFont.font(size: 12 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(item.label.uppercased())
                            .font(theme.currentFont.font(size: 7 * scale, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                            .tracking(0.5)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .cardBackground(theme, radius: 10)
    }
}

// MARK: - Breakdown Card

/// Share of tracked time per session type.
private struct BreakdownCard: View {
    let snapshot: StatsSnapshot
    let unit: StatsTimeUnit
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        let parts: [(label: String, seconds: Int, color: Color)] = [
            ("Focus", snapshot.workSeconds, theme.colors.accent),
            ("Stopwatch", snapshot.stopwatchSeconds, theme.colors.accent.opacity(0.5)),
            ("Break", snapshot.breakSeconds, theme.colors.breakRing)
        ]
        let visible = parts.filter { $0.seconds > 0 }
        let total = max(parts.reduce(0) { $0 + $1.seconds }, 1)

        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Breakdown", theme: theme, scale: scale)

            GeometryReader { geo in
                let gaps = CGFloat(max(visible.count - 1, 0)) * 2
                HStack(spacing: 2) {
                    if visible.isEmpty {
                        Capsule().fill(theme.colors.ringTrack)
                    } else {
                        ForEach(visible, id: \.label) { part in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(part.color)
                                .frame(width: max((geo.size.width - gaps) * CGFloat(part.seconds) / CGFloat(total), 2))
                        }
                    }
                }
            }
            .frame(height: 6 * scale)

            HStack(spacing: 12) {
                ForEach(parts, id: \.label) { part in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(part.color)
                            .frame(width: 6, height: 6)
                        Text(part.label)
                            .font(theme.currentFont.font(size: 8 * scale, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                        Text(unit.format(part.seconds))
                            .font(theme.currentFont.font(size: 8 * scale, weight: .semibold))
                            .foregroundColor(theme.colors.text)
                    }
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .cardBackground(theme, radius: 10)
    }
}

// MARK: - Sessions Card

/// Every session in the period, newest first, in a list that scrolls within the
/// height it is given.
private struct SessionsCard: View {
    let sessions: [StatsSessionItem]
    /// Tasks a focus session can be moved to (right click on a row).
    let tasks: [TaskItem]
    let taskTitle: (UUID?) -> String?
    let menuTitle: (TaskItem) -> String
    let onAssign: (StatsSessionItem, UUID?) -> Void
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionHeader(title: "Sessions", theme: theme, scale: scale)
                Spacer()
                if !sessions.isEmpty {
                    let focus = sessions.filter(\.isFocus).count
                    let breaks = sessions.count - focus
                    Text("\(focus) focus · \(breaks) break\(breaks == 1 ? "" : "s")")
                        .font(theme.currentFont.font(size: 8 * scale, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }

            if sessions.isEmpty {
                Text("No sessions in this period")
                    .font(theme.currentFont.font(size: 10 * scale))
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            SessionRow(session: session, theme: theme, scale: scale, taskTitle: taskTitle(session.taskID))
                                .contextMenu {
                                    SessionTaskMenu(session: session, tasks: tasks, menuTitle: menuTitle, onAssign: onAssign)
                                }
                            if index < sessions.count - 1 {
                                Divider().background(theme.colors.ringTrack)
                            }
                        }
                    }
                    .padding(.trailing, 6)
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .cardBackground(theme, radius: 10)
    }
}
