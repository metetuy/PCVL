import SwiftUI
import Charts

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel
    @ObservedObject var theme: ThemeManager
    var isExpanded: Bool = false
    var onToggleFullscreen: () -> Void

    @State private var hoveredBucketID: Int?
    @State private var hoveredHour: Int?
    @State private var hoveredWeekday: Int?

    private var snapshot: StatsSnapshot { viewModel.snapshot }

    /// Font/spacing multiplier: 1 in the popup, larger when zoomed to fill the screen.
    private var s: CGFloat { isExpanded ? 1.35 : 1 }

    var body: some View {
        Group {
            if isExpanded {
                expandedLayout
            } else {
                compactLayout
            }
        }
        .onAppear { viewModel.refresh() }
        .onChange(of: snapshot.interval) { _, _ in
            hoveredBucketID = nil
            hoveredHour = nil
            hoveredWeekday = nil
        }
    }

    // MARK: - Layouts

    private var compactLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                controlsBar
                    .padding(.top, 10)
                periodNavigator
                summaryRow
                mainChartCard(height: 70)
                insightsCard(columns: 3)
                breakdownCard
                sessionsCard(limit: 15)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 14)
        }
    }

    private var expandedLayout: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14 * s) {
                HStack(spacing: 12 * s) {
                    rangePicker
                    Spacer()
                    periodNavigator
                        .frame(maxWidth: 420 * s)
                    Spacer()
                    unitToggle
                    expandButton
                }
                .padding(.top, 18)

                expandedKPIRow

                HStack(alignment: .top, spacing: 14 * s) {
                    VStack(spacing: 14 * s) {
                        mainChartCard(height: 260 * s)
                        HStack(alignment: .top, spacing: 14 * s) {
                            hourlyChartCard
                            weekdayChartCard
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14 * s) {
                        insightsCard(columns: 2)
                        breakdownCard
                        sessionsCard(limit: 60)
                    }
                    .frame(width: 340 * s)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 1600)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: 6) {
            rangePicker
            Spacer(minLength: 0)
            unitToggle
            expandButton
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsRange.allCases) { range in
                segmentButton(
                    title: range.label,
                    isSelected: viewModel.range == range
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.range = range
                    }
                }
            }
        }
        .padding(2 * s)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }

    /// Minute based or hour based presentation of all focus totals.
    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach(StatsTimeUnit.allCases) { unit in
                segmentButton(
                    title: unit.symbol,
                    isSelected: viewModel.unit == unit
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.unit = unit
                    }
                }
            }
        }
        .padding(2 * s)
        .background(theme.colors.surface)
        .clipShape(Capsule())
        .help("Show time in minutes or hours")
    }

    private func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(theme.currentFont.font(size: 9 * s, weight: .medium))
                .foregroundColor(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                .padding(.horizontal, 6 * s)
                .padding(.vertical, 4 * s)
                .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .hoverEffect()
    }

    private var expandButton: some View {
        Button(action: onToggleFullscreen) {
            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 20 * s, height: 20 * s)
                .background(theme.colors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .hoverEffect()
        .help(isExpanded ? "Exit full screen" : "Full screen")
    }

    private var periodNavigator: some View {
        HStack(spacing: 6 * s) {
            navButton(icon: "chevron.left", enabled: viewModel.canGoBack, action: viewModel.goBack)

            Button(action: viewModel.goToCurrent) {
                Text(viewModel.periodTitle)
                    .font(theme.currentFont.font(size: 10.5 * s, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .help(viewModel.isCurrentPeriod ? "" : "Back to current period")

            navButton(icon: "chevron.right", enabled: viewModel.canGoForward, action: viewModel.goForward)

            Spacer(minLength: 4)

            if let change = viewModel.changeText {
                HStack(spacing: 3 * s) {
                    Image(systemName: viewModel.changeIsPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(theme.currentFont.font(size: 7 * s, weight: .bold))
                        .foregroundColor(viewModel.changeIsPositive ? theme.colors.accent : theme.colors.textSecondary)
                    Text(change)
                        .font(theme.currentFont.font(size: 9 * s, weight: .semibold))
                        .foregroundColor(theme.colors.text)
                    Text(viewModel.comparisonLabel)
                        .font(theme.currentFont.font(size: 8 * s))
                        .foregroundColor(theme.colors.textSecondary)
                }
                .lineLimit(1)
            }
        }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 8 * s, weight: .bold))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 18 * s, height: 18 * s)
                .background(theme.colors.surface)
                .clipShape(Circle())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .hoverEffect()
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 8) {
            statCard(value: viewModel.format(snapshot.focusSeconds), label: "Focus")
            statCard(value: "\(snapshot.focusSessionCount)", label: "Sessions")
            statCard(value: "\(snapshot.currentStreak)d", label: "Streak", valueColor: theme.colors.accent)
        }
    }

    private var expandedKPIRow: some View {
        HStack(spacing: 10 * s) {
            statCard(value: viewModel.format(snapshot.focusSeconds), label: "Total focus")
            statCard(value: "\(snapshot.focusSessionCount)", label: "Sessions")
            statCard(value: viewModel.format(snapshot.dailyAverageSeconds), label: "Daily average")
            statCard(value: viewModel.format(snapshot.averageSessionSeconds), label: "Avg session")
            statCard(value: viewModel.activeDaysText, label: "Active days")
            statCard(value: "\(snapshot.currentStreak)d", label: "Streak", valueColor: theme.colors.accent)
        }
    }

    private func statCard(value: String, label: String, valueColor: Color? = nil) -> some View {
        VStack(spacing: 2 * s) {
            Text(value)
                .font(theme.currentFont.font(size: (isExpanded ? 20 : 17) * s, weight: .bold, design: .rounded))
                .foregroundColor(valueColor ?? theme.colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .tracking(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 * s)
        .padding(.horizontal, 4)
        .cardBackground(theme, radius: 8 * s)
    }

    // MARK: - Main Chart

    private var hoveredBucket: StatsBucket? {
        hoveredBucketID.flatMap { id in snapshot.buckets.first { $0.id == id } }
    }

    private func mainChartCard(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            HStack(spacing: 6) {
                if let bucket = hoveredBucket {
                    sectionHeader(viewModel.bucketTitle(bucket).uppercased())
                    Spacer()
                    Text(viewModel.format(bucket.focusSeconds))
                        .font(theme.currentFont.font(size: 9 * s, weight: .bold))
                        .foregroundColor(theme.colors.text)
                    Text("· \(bucket.sessions) sessions")
                        .font(theme.currentFont.font(size: 8 * s))
                        .foregroundColor(theme.colors.textSecondary)
                } else {
                    sectionHeader(chartTitle)
                    Spacer()
                    if snapshot.bucketAverageSeconds > 0 {
                        Text("avg \(viewModel.format(snapshot.bucketAverageSeconds))")
                            .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
            .lineLimit(1)

            mainChart
                .frame(height: height)
                .overlay {
                    if snapshot.focusSeconds == 0 {
                        emptyText("No focus time in this period")
                    }
                }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    private var chartTitle: String {
        switch snapshot.bucketComponent {
        case .hour: return "FOCUS BY HOUR"
        case .day: return "FOCUS BY DAY"
        case .month: return "FOCUS BY MONTH"
        default: return "FOCUS BY YEAR"
        }
    }

    private var mainChart: some View {
        Chart {
            ForEach(snapshot.buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.interval.start, unit: snapshot.bucketComponent),
                    y: .value(viewModel.unit.axisTitle, viewModel.chartValue(bucket.focusSeconds))
                )
                .foregroundStyle(barColor(isHighlighted: bucket.id == hoveredBucketID || (hoveredBucketID == nil && bucket.isCurrent)))
                .cornerRadius(isExpanded ? 3 : 2)
            }

            if snapshot.bucketAverageSeconds > 0 {
                RuleMark(y: .value("Average", viewModel.chartValue(snapshot.bucketAverageSeconds)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(theme.colors.textSecondary.opacity(0.6))
            }
        }
        .chartXAxis {
            AxisMarks(values: mainAxisDates) { value in
                AxisValueLabel(centered: true, collisionResolution: .disabled) {
                    if let date = value.as(Date.self) {
                        Text(viewModel.axisLabel(for: date))
                            .font(theme.currentFont.font(size: 7 * s))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis { valueAxis(desiredCount: isExpanded ? 5 : 3) }
        .chartOverlay { proxy in
            hoverLayer(proxy: proxy) { x in
                guard let date: Date = proxy.value(atX: x) else { return nil }
                return snapshot.buckets.first { $0.interval.contains(date) && date < $0.interval.end }?.id
            } onChange: { hoveredBucketID = $0 }
        }
    }

    private var mainAxisDates: [Date] {
        let stride = viewModel.axisLabelStride(compact: !isExpanded)
        return snapshot.buckets.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { $0.element.interval.start }
    }

    // MARK: - Distribution Charts (expanded)

    private var hourlyChartCard: some View {
        let peak = snapshot.peakHour
        return VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                if let hour = hoveredHour {
                    sectionHeader(String(format: "%02d:00 – %02d:00", hour, (hour + 1) % 24))
                    Spacer()
                    valueLabel(viewModel.format(snapshot.hourly[hour]))
                } else {
                    sectionHeader("TIME OF DAY")
                    Spacer()
                    if peak != nil {
                        Text("peak \(viewModel.peakHourText)")
                            .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }

            Chart {
                ForEach(0..<24, id: \.self) { hour in
                    BarMark(
                        x: .value("Hour", hour),
                        y: .value(viewModel.unit.axisTitle, viewModel.chartValue(snapshot.hourly[hour])),
                        width: .ratio(0.7)
                    )
                    .foregroundStyle(barColor(isHighlighted: hoveredHour.map { $0 == hour } ?? (hour == peak)))
                    .cornerRadius(2)
                }
            }
            .chartXScale(domain: -0.5...23.5)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(theme.currentFont.font(size: 7 * s))
                                .foregroundColor(theme.colors.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis { valueAxis(desiredCount: 3) }
            .chartOverlay { proxy in
                hoverLayer(proxy: proxy) { x in
                    guard let value: Double = proxy.value(atX: x) else { return nil }
                    let hour = Int(value.rounded())
                    return (0..<24).contains(hour) ? hour : nil
                } onChange: { hoveredHour = $0 }
            }
            .frame(height: 120 * s)
            .overlay {
                if snapshot.focusSeconds == 0 { emptyText("No data") }
            }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    private var weekdayChartCard: some View {
        let peak = snapshot.peakWeekday
        let names = StatsViewModel.weekdayNames
        return VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                if let day = hoveredWeekday {
                    sectionHeader(names[day].uppercased())
                    Spacer()
                    valueLabel(viewModel.format(snapshot.weekday[day]))
                } else {
                    sectionHeader("BY WEEKDAY")
                    Spacer()
                    if peak != nil {
                        Text("best \(viewModel.peakWeekdayText)")
                            .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }

            Chart {
                ForEach(0..<7, id: \.self) { day in
                    BarMark(
                        x: .value("Weekday", names[day]),
                        y: .value(viewModel.unit.axisTitle, viewModel.chartValue(snapshot.weekday[day]))
                    )
                    .foregroundStyle(barColor(isHighlighted: hoveredWeekday.map { $0 == day } ?? (day == peak)))
                    .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name)
                                .font(theme.currentFont.font(size: 7 * s))
                                .foregroundColor(theme.colors.textSecondary)
                        }
                    }
                }
            }
            .chartYAxis { valueAxis(desiredCount: 3) }
            .chartOverlay { proxy in
                hoverLayer(proxy: proxy) { x in
                    guard let name: String = proxy.value(atX: x) else { return nil }
                    return names.firstIndex(of: name)
                } onChange: { hoveredWeekday = $0 }
            }
            .frame(height: 120 * s)
            .overlay {
                if snapshot.focusSeconds == 0 { emptyText("No data") }
            }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    // MARK: - Chart Helpers

    private func barColor(isHighlighted: Bool) -> Color {
        isHighlighted ? theme.colors.accent : theme.colors.accent.opacity(0.3)
    }

    private func valueAxis(desiredCount: Int) -> some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: desiredCount)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(theme.colors.ringTrack)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(viewModel.unit.formatAxis(number))
                        .font(theme.currentFont.font(size: 7 * s))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }
        }
    }

    /// Transparent layer that maps the pointer position to a chart element id.
    private func hoverLayer(
        proxy: ChartProxy,
        resolve: @escaping (CGFloat) -> Int?,
        onChange: @escaping (Int?) -> Void
    ) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        guard let plotFrame = proxy.plotFrame else { return }
                        let x = location.x - geo[plotFrame].origin.x
                        onChange(x >= 0 && x <= geo[plotFrame].width ? resolve(x) : nil)
                    case .ended:
                        onChange(nil)
                    }
                }
        }
    }

    // MARK: - Insights

    private func insightsCard(columns: Int) -> some View {
        let items: [(label: String, value: String)] = [
            ("Daily avg", viewModel.format(snapshot.dailyAverageSeconds)),
            ("Avg session", viewModel.format(snapshot.averageSessionSeconds)),
            ("Longest", viewModel.format(snapshot.longestSessionSeconds)),
            ("Best day", snapshot.bestDay.map { viewModel.format($0.seconds) } ?? "—"),
            ("Active days", viewModel.activeDaysText),
            ("Peak hour", viewModel.peakHourText),
            ("Best weekday", viewModel.peakWeekdayText),
            ("Best streak", "\(snapshot.longestStreak)d"),
            ("Focus share", viewModel.focusShareText)
        ]
        let grid = Array(repeating: GridItem(.flexible(), spacing: 6 * s, alignment: .leading), count: columns)

        return VStack(alignment: .leading, spacing: 8 * s) {
            HStack {
                sectionHeader("INSIGHTS")
                Spacer()
                if snapshot.bestDay != nil {
                    Text("best day \(viewModel.bestDayText)")
                        .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }

            LazyVGrid(columns: grid, alignment: .leading, spacing: 8 * s) {
                ForEach(items, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.value)
                            .font(theme.currentFont.font(size: 11 * s, weight: .bold, design: .rounded))
                            .foregroundColor(theme.colors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(item.label.uppercased())
                            .font(theme.currentFont.font(size: 7 * s, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                            .tracking(0.5)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    // MARK: - Breakdown

    /// Proportion of tracked time per session type.
    private var breakdownCard: some View {
        let parts: [(label: String, seconds: Int, color: Color)] = [
            ("Focus", snapshot.workSeconds, theme.colors.accent),
            ("Stopwatch", snapshot.stopwatchSeconds, theme.colors.accent.opacity(0.5)),
            ("Break", snapshot.breakSeconds, theme.colors.breakRing)
        ]
        let total = max(parts.reduce(0) { $0 + $1.seconds }, 1)

        return VStack(alignment: .leading, spacing: 8 * s) {
            sectionHeader("BREAKDOWN")

            GeometryReader { geo in
                let visible = parts.filter { $0.seconds > 0 }
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
            .frame(height: 6 * s)

            HStack(spacing: 10 * s) {
                ForEach(parts, id: \.label) { part in
                    HStack(spacing: 4 * s) {
                        Circle()
                            .fill(part.color)
                            .frame(width: 5 * s, height: 5 * s)
                        Text(part.label)
                            .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                        Text(viewModel.format(part.seconds))
                            .font(theme.currentFont.font(size: 8 * s, weight: .semibold))
                            .foregroundColor(theme.colors.text)
                    }
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    // MARK: - Sessions

    private func sessionsCard(limit: Int) -> some View {
        let sessions = Array(snapshot.sessions.prefix(limit))

        return VStack(alignment: .leading, spacing: 6 * s) {
            HStack {
                sectionHeader("SESSIONS")
                Spacer()
                if snapshot.sessions.count > sessions.count {
                    Text("latest \(sessions.count) of \(snapshot.sessions.count)")
                        .font(theme.currentFont.font(size: 8 * s))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }

            if sessions.isEmpty {
                emptyText("No sessions in this period")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        sessionRow(session)

                        if index < sessions.count - 1 {
                            Divider()
                                .background(theme.colors.ringTrack)
                        }
                    }
                }
            }
        }
        .padding(10 * s)
        .cardBackground(theme, radius: 8 * s)
    }

    private func sessionRow(_ session: StatsSessionItem) -> some View {
        HStack(spacing: 7 * s) {
            // Type badge
            Circle()
                .fill(badgeColor(for: session.type))
                .frame(width: 5 * s, height: 5 * s)

            // Date
            Text(viewModel.sessionDateText(session.date))
                .font(theme.currentFont.font(size: 10 * s))
                .foregroundColor(theme.colors.text)

            Spacer()

            // Duration
            Text(viewModel.sessionDurationText(session.duration))
                .font(theme.currentFont.font(size: 10 * s, weight: .medium, design: .monospaced))
                .foregroundColor(theme.colors.textSecondary)

            // Type label
            Text(typeLabel(session.type))
                .font(theme.currentFont.font(size: 8 * s, weight: .medium))
                .foregroundColor(badgeColor(for: session.type))
                .padding(.horizontal, 5 * s)
                .padding(.vertical, 2 * s)
                .background(badgeColor(for: session.type).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 5 * s)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(theme.currentFont.font(size: 8 * s, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(theme.colors.textSecondary)
    }

    private func valueLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 9 * s, weight: .bold))
            .foregroundColor(theme.colors.text)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 11 * s))
            .foregroundColor(theme.colors.textSecondary)
    }

    private func badgeColor(for type: SessionType) -> Color {
        switch type {
        case .work: return theme.colors.timerRing
        case .shortBreak: return theme.colors.breakRing
        case .stopwatch: return theme.colors.accent
        }
    }

    private func typeLabel(_ type: SessionType) -> String {
        switch type {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .stopwatch: return "Free"
        }
    }
}

// MARK: - Card Background

private extension View {
    /// The shared surface card look used across the stats screen.
    func cardBackground(_ theme: ThemeManager, radius: CGFloat = 8) -> some View {
        self
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }
}
