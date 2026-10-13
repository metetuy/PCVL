import SwiftUI
import Charts

// Statistics building blocks shared by the panel's stats tab and the analytics window.
// `scale` = 1 is the compact panel size.

// MARK: - Card

extension View {
    /// The surface card look used across the app.
    func cardBackground(_ theme: ThemeManager, radius: CGFloat = 8) -> some View {
        self
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }
}

/// Small uppercase tracked label used as a card title.
struct SectionHeader: View {
    let title: String
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        Text(title.uppercased())
            .font(theme.currentFont.font(size: 8 * scale, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(theme.colors.textSecondary)
            .lineLimit(1)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    var valueColor: Color?
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    /// Shows a flame after the value (the streak card): burning when true, unlit when false.
    var flameLit: Bool?

    var body: some View {
        VStack(spacing: 2 * scale) {
            HStack(spacing: 3 * scale) {
                Text(value)
                    .font(theme.currentFont.font(size: 17 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(valueColor ?? theme.colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                if let flameLit {
                    FlameIcon(lit: flameLit, size: 14 * scale, theme: theme)
                }
            }
            Text(label.uppercased())
                .font(theme.currentFont.font(size: 8 * scale, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .tracking(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8 * scale)
        .padding(.horizontal, 4)
        .cardBackground(theme, radius: 8 * scale)
    }
}

// MARK: - Flame

/// A flickering flame for the streak. Two layered flame glyphs (red-orange body, yellow core)
/// sway and stretch from their base on a few out-of-phase sine waves, so it never visibly loops.
/// Unlit (grey, still) when the streak is broken; still when Reduce Motion is on.
struct FlameIcon: View {
    let lit: Bool
    let size: CGFloat
    @ObservedObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let red = Color(red: 0.93, green: 0.26, blue: 0.16)
    private static let orange = Color(red: 1.0, green: 0.55, blue: 0.13)
    private static let yellow = Color(red: 1.0, green: 0.85, blue: 0.35)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !lit || reduceMotion)) { context in
            flame(at: lit && !reduceMotion ? context.date.timeIntervalSinceReferenceDate : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func flame(at t: TimeInterval) -> some View {
        if lit {
            let stretch = 0.06 * sin(t * 9.1) + 0.04 * sin(t * 13.7)
            let sway = 3.5 * sin(t * 5.3) + 1.5 * sin(t * 11.9)
            ZStack(alignment: .bottom) {
                Image(systemName: "flame.fill")
                    .font(.system(size: size))
                    .foregroundStyle(LinearGradient(colors: [Self.red, Self.orange], startPoint: .bottom, endPoint: .top))
                    .scaleEffect(x: 1 - stretch * 0.5, y: 1 + stretch, anchor: .bottom)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                Image(systemName: "flame.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(Self.yellow)
                    .scaleEffect(y: 1 + 0.12 * sin(t * 15.3 + 1), anchor: .bottom)
                    .rotationEffect(.degrees(-sway * 0.8), anchor: .bottom)
                    .opacity(0.85 + 0.15 * sin(t * 17.1))
            }
            .shadow(color: Self.orange.opacity(0.45 + 0.15 * sin(t * 7.7)), radius: size * 0.25)
        } else {
            Image(systemName: "flame")
                .font(.system(size: size))
                .foregroundColor(theme.colors.textSecondary.opacity(0.6))
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: StatsSessionItem
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 7 * scale) {
            Circle()
                .fill(badgeColor)
                .frame(width: 5 * scale, height: 5 * scale)

            Text(StatsFormat.sessionDate(session.date))
                .font(theme.currentFont.font(size: 10 * scale))
                .foregroundColor(theme.colors.text)
                .lineLimit(1)

            Spacer()

            Text(StatsFormat.sessionDuration(session.duration))
                .font(theme.currentFont.font(size: 10 * scale, weight: .medium, design: .monospaced))
                .foregroundColor(theme.colors.textSecondary)

            Text(StatsFormat.typeLabel(session.type))
                .font(theme.currentFont.font(size: 8 * scale, weight: .medium))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 2 * scale)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 5 * scale)
    }

    private var badgeColor: Color {
        switch session.type {
        case .work: return theme.colors.timerRing
        case .shortBreak: return theme.colors.breakRing
        case .stopwatch: return theme.colors.accent
        }
    }
}

// MARK: - Segmented Control

/// Capsule segmented control matching the timer's mode toggle.
struct CapsuleSegmentedControl<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(theme.currentFont.font(size: 9 * scale, weight: .medium))
                        .foregroundColor(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                        .padding(.horizontal, 7 * scale)
                        .padding(.vertical, 4 * scale)
                        .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
                .hoverEffect()
            }
        }
        .padding(2 * scale)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }
}

// MARK: - Focus Bar Chart

/// Focus time per bucket (hour/day/month/year) with a dashed average line.
/// The current bucket is highlighted; hovering highlights and reports a bar instead.
struct FocusBarChart: View {
    let buckets: [StatsBucket]
    let component: Calendar.Component
    let unit: StatsTimeUnit
    let averageSeconds: Int
    /// Maximum number of x-axis labels to show.
    var maxAxisLabels: Int = 7
    let axisLabel: (Date) -> String
    @Binding var hoveredID: Int?
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.interval.start, unit: component),
                    y: .value(unit.axisTitle, unit.value(bucket.focusSeconds))
                )
                .foregroundStyle(barColor(isHighlighted: isHighlighted(bucket)))
                .cornerRadius(2 * scale)
            }

            if averageSeconds > 0 {
                RuleMark(y: .value("Average", unit.value(averageSeconds)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(theme.colors.textSecondary.opacity(0.6))
            }
        }
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisValueLabel(centered: true) {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(date))
                            .font(theme.currentFont.font(size: 7 * scale))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis { ValueAxis(unit: unit, theme: theme, scale: scale, desiredCount: scale > 1 ? 4 : 3).body }
        .chartOverlay { proxy in
            ChartHoverLayer(proxy: proxy) { x in
                guard let date: Date = proxy.value(atX: x) else { return nil }
                return buckets.first { date >= $0.interval.start && date < $0.interval.end }?.id
            } onChange: { hoveredID = $0 }
        }
    }

    private func isHighlighted(_ bucket: StatsBucket) -> Bool {
        if let hoveredID { return bucket.id == hoveredID }
        return bucket.isCurrent
    }

    private func barColor(isHighlighted: Bool) -> Color {
        isHighlighted ? theme.colors.accent : theme.colors.accent.opacity(0.3)
    }

    private var axisDates: [Date] {
        let stride = max(1, Int((Double(buckets.count) / Double(maxAxisLabels)).rounded(.up)))
        return buckets.enumerated()
            .filter { $0.offset % stride == 0 }
            .map { $0.element.interval.start }
    }
}

// MARK: - Distribution Bar Chart

/// Bars over a fixed set of categories (hours of day, weekdays). The peak is
/// highlighted; hovering highlights and reports a bar instead.
struct DistributionBarChart: View {
    let values: [Int]
    let labels: [String]
    /// Indices that get an axis label.
    let labeledIndices: [Int]
    let unit: StatsTimeUnit
    let peakIndex: Int?
    @Binding var hoveredIndex: Int?
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        // Categorical x (one band per label) sizes the bars without a numeric scale.
        Chart {
            ForEach(values.indices, id: \.self) { index in
                BarMark(
                    x: .value("Category", labels[index]),
                    y: .value(unit.axisTitle, unit.value(values[index]))
                )
                .foregroundStyle(
                    (hoveredIndex.map { $0 == index } ?? (index == peakIndex))
                        ? theme.colors.accent
                        : theme.colors.accent.opacity(0.3)
                )
                .cornerRadius(2 * scale)
            }
        }
        .chartXAxis {
            // Categorical axes ignore a values filter, so unlabeled categories render empty.
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self),
                       let index = labels.firstIndex(of: label),
                       labeledIndices.contains(index) {
                        Text(label)
                            .font(theme.currentFont.font(size: 7 * scale))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }
        }
        .chartYAxis { ValueAxis(unit: unit, theme: theme, scale: scale, desiredCount: 3).body }
        .chartOverlay { proxy in
            ChartHoverLayer(proxy: proxy) { x in
                guard let label: String = proxy.value(atX: x) else { return nil }
                return labels.firstIndex(of: label)
            } onChange: { hoveredIndex = $0 }
        }
    }
}

// MARK: - Chart Helpers

/// Trailing value axis with recessive grid lines and unit-formatted labels.
private struct ValueAxis {
    let unit: StatsTimeUnit
    let theme: ThemeManager
    let scale: CGFloat
    let desiredCount: Int

    var body: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: desiredCount)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(theme.colors.ringTrack)
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(unit.formatAxis(number))
                        .font(theme.currentFont.font(size: 7 * scale))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }
        }
    }
}

/// Transparent layer that maps the pointer's x position inside the plot to an element id.
private struct ChartHoverLayer: View {
    let proxy: ChartProxy
    let resolve: (CGFloat) -> Int?
    let onChange: (Int?) -> Void

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        guard let plotFrame = proxy.plotFrame else { return }
                        let plot = geo[plotFrame]
                        let x = location.x - plot.origin.x
                        onChange(x >= 0 && x <= plot.width ? resolve(x) : nil)
                    case .ended:
                        onChange(nil)
                    }
                }
        }
    }
}
