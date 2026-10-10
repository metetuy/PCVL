import SwiftUI
import Charts

// MARK: - Task Analytics Section

/// The top of the analytics screen: where focus went, per task, over all time. A
/// task's hours are the plain sum of its sessions, independent of the period the
/// time charts below are showing.
struct TaskAnalyticsSection: View {
    @ObservedObject var viewModel: TaskAnalyticsViewModel
    @ObservedObject var theme: ThemeManager
    let isWide: Bool
    let onShowTasks: () -> Void

    private let s: CGFloat = 1.2
    private let detailWidth: CGFloat = 420

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.summaries.isEmpty {
                emptyCard
            } else if isWide {
                HStack(alignment: .top, spacing: 14) {
                    totalsCard
                    detailCard
                        .frame(width: detailWidth)
                }
            } else {
                totalsCard
                detailCard
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Tasks")
                .font(theme.currentFont.font(size: 20, weight: .semibold))
                .foregroundColor(theme.colors.text)
            Text("All time")
                .font(theme.currentFont.font(size: 11, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
            Spacer()
            if viewModel.totalFocusSeconds > 0 {
                Text("\(viewModel.durationText(viewModel.totalFocusSeconds)) of focus recorded")
                    .font(theme.currentFont.font(size: 11, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
            }
        }
    }

    // MARK: - Totals

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Total by task", theme: theme, scale: s)
            VStack(spacing: 2) {
                ForEach(viewModel.summaries) { summary in
                    TaskTotalRow(
                        summary: summary,
                        fraction: viewModel.barFraction(summary),
                        duration: viewModel.durationText(summary.totalSeconds),
                        share: viewModel.shareText(summary),
                        isSelected: summary.id == viewModel.selectedID,
                        theme: theme
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.select(summary.id)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(theme, radius: 10)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailCard: some View {
        if let summary = viewModel.selected {
            TaskDetailCard(viewModel: viewModel, summary: summary, theme: theme, onShowTasks: onShowTasks)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(theme.currentFont.font(size: 22, weight: .light))
                .foregroundColor(theme.colors.textSecondary)
            Text("Add tasks to see where your focus goes")
                .font(theme.currentFont.font(size: 13, weight: .semibold))
                .foregroundColor(theme.colors.text)
            Button("Open Tasks", action: onShowTasks)
                .buttonStyle(.plain)
                .font(theme.currentFont.font(size: 11, weight: .medium))
                .foregroundColor(theme.colors.accent)
                .hoverEffect()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardBackground(theme, radius: 10)
    }
}

// MARK: - Task Total Row

/// One task in the totals list: title, all-time total, share and a bar relative to
/// the largest task.
private struct TaskTotalRow: View {
    let summary: TaskSummary
    let fraction: Double
    let duration: String
    let share: String
    let isSelected: Bool
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(summary.title)
                        .font(theme.currentFont.font(size: 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(summary.isUntagged || summary.isDone ? theme.colors.textSecondary : theme.colors.text)
                        .strikethrough(summary.isDone, color: theme.colors.textSecondary)
                        .italic(summary.isUntagged)
                        .lineLimit(1)
                    if summary.isDone {
                        badge("DONE")
                    }
                    Spacer(minLength: 8)
                    Text(summary.sessions > 0 ? duration : "—")
                        .font(theme.currentFont.font(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(theme.colors.text)
                    Text(summary.sessions > 0 ? share : "")
                        .font(theme.currentFont.font(size: 10, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 34, alignment: .trailing)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.colors.ringTrack)
                        Capsule()
                            .fill(barColor)
                            .frame(width: summary.totalSeconds > 0 ? max(geo.size.width * fraction, 3) : 0)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? theme.colors.accent.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private var barColor: Color {
        if summary.isUntagged { return theme.colors.textSecondary.opacity(0.5) }
        return summary.isDone ? theme.colors.accent.opacity(0.5) : theme.colors.accent
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 8, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(theme.colors.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(theme.colors.textSecondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Task Detail Card

/// The selected task: its total, session stats, when it was worked on, and its
/// running total over time. For the time without a task it offers to assign it.
private struct TaskDetailCard: View {
    @ObservedObject var viewModel: TaskAnalyticsViewModel
    let summary: TaskSummary
    @ObservedObject var theme: ThemeManager
    let onShowTasks: () -> Void

    @State private var pendingAssignment: TaskItem?

    private let s: CGFloat = 1.2

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.title)
                    .font(theme.currentFont.font(size: 15, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .italic(summary.isUntagged)
                    .lineLimit(2)
                Spacer()
                if summary.isDone {
                    SectionHeader(title: "Done", theme: theme, scale: s)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.durationText(summary.totalSeconds))
                    .font(theme.currentFont.font(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(theme.colors.text)
                    .contentTransition(.numericText())
                Text("total focus · \(viewModel.shareText(summary)) of all focus")
                    .font(theme.currentFont.font(size: 10.5, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
            }

            statsGrid

            if summary.isUntagged {
                untaggedNote
            }

            progressChart
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(theme, radius: 10)
        .alert(
            "Assign to “\(pendingAssignment?.title ?? "")”?",
            isPresented: Binding(get: { pendingAssignment != nil }, set: { if !$0 { pendingAssignment = nil } })
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Assign") {
                if let task = pendingAssignment {
                    viewModel.assignUntagged(to: task.id)
                }
            }
        } message: {
            Text("All \(summary.sessions) focus sessions without a task (\(viewModel.durationText(summary.totalSeconds))) will count toward it. Single sessions can be moved back from the session list (right click).")
        }
    }

    private var statsGrid: some View {
        let items: [(label: String, value: String)] = [
            ("Sessions", "\(summary.sessions)"),
            ("Avg session", viewModel.durationText(summary.averageSeconds)),
            ("Longest", viewModel.durationText(summary.longestSeconds)),
            ("Active days", "\(summary.activeDays)"),
            ("First worked", viewModel.firstWorkedText(summary)),
            ("Last worked", viewModel.lastWorkedText(summary))
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .leading), count: 3), alignment: .leading, spacing: 10) {
            ForEach(items, id: \.label) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.value)
                        .font(theme.currentFont.font(size: 12 * s, weight: .bold, design: .rounded))
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

    // MARK: Untagged

    private var untaggedNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus recorded without a task, such as sessions from before tasks existed. Assign it to a task to count toward that task.")
                .font(theme.currentFont.font(size: 10.5))
                .foregroundColor(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.hasTasks {
                Menu {
                    ForEach(viewModel.tasks) { task in
                        Button(task.isDone ? "\(task.title) (done)" : task.title) {
                            pendingAssignment = task
                        }
                    }
                } label: {
                    assignLabel("Assign all to a task…")
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .hoverEffect()
            } else {
                Button(action: onShowTasks) {
                    assignLabel("Create a task first")
                }
                .buttonStyle(.plain)
                .hoverEffect()
            }
        }
    }

    private func assignLabel(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.right.circle")
                .font(theme.currentFont.font(size: 11, weight: .medium))
            Text(text)
                .font(theme.currentFont.font(size: 11, weight: .semibold))
        }
        .foregroundColor(theme.colors.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.colors.accent.opacity(0.12))
        .clipShape(Capsule())
        .contentShape(Capsule())
    }

    // MARK: Running Total

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Running total", theme: theme, scale: s)
            if viewModel.progress.count < 2 {
                Text("No sessions yet")
                    .font(theme.currentFont.font(size: 10, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(viewModel.progress) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Hours", Double(point.totalSeconds) / 3600)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.colors.accent.opacity(0.28), theme.colors.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Hours", Double(point.totalSeconds) / 3600)
                    )
                    .foregroundStyle(theme.colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(theme.colors.ringTrack)
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text(hours < 1 && hours > 0 ? "\(Int(hours * 60))m" : "\(Int(hours))h")
                                    .font(theme.currentFont.font(size: 8 * s))
                                    .foregroundColor(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(theme.currentFont.font(size: 8 * s))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .frame(height: 130)
            }
        }
    }
}
