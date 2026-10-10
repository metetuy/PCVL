import SwiftUI

// MARK: - Task Analytics Section

/// The top of the analytics screen: where focus went, per task, over all time.
/// Every task is a card whose total is drawn as hour blocks: a task's hours are the
/// plain sum of its sessions, independent of the period the time charts below show.
/// Selecting a card lists the sessions behind its total.
struct TaskAnalyticsSection: View {
    @ObservedObject var viewModel: TaskAnalyticsViewModel
    @ObservedObject var theme: ThemeManager
    let onShowTasks: () -> Void

    @State private var pendingAssignment: TaskItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.summaries.isEmpty {
                emptyCard
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(viewModel.summaries) { summary in
                        TaskCard(
                            summary: summary,
                            viewModel: viewModel,
                            isCurrent: summary.taskID != nil && summary.taskID == viewModel.activeTaskID,
                            isSelected: summary.id == viewModel.selectedID,
                            theme: theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.toggleSelection(summary.id)
                            }
                        }
                    }
                }

                if let selected = viewModel.selected {
                    sessionsPanel(selected)
                        .transition(.opacity)
                }
            }
        }
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
            let untagged = viewModel.untagged
            Text("All \(untagged?.sessions ?? 0) focus sessions without a task (\(viewModel.durationText(untagged?.totalSeconds ?? 0))) will count toward it. Single sessions can be moved back with a right click on them.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Tasks")
                    .font(theme.currentFont.font(size: 20, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                Text("All time")
                    .font(theme.currentFont.font(size: 11, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
                Spacer()
                if !viewModel.summaries.isEmpty {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.colors.accent)
                            .frame(width: 8, height: 8)
                        Text(viewModel.blockLegend)
                    }
                    .font(theme.currentFont.font(size: 10, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
                }
            }
            if viewModel.totalFocusSeconds > 0 {
                Text(summaryLine)
                    .font(theme.currentFont.font(size: 11))
                    .foregroundColor(theme.colors.textSecondary)
            }
        }
    }

    private var summaryLine: String {
        var parts = ["\(viewModel.durationText(viewModel.totalFocusSeconds)) of focus"]
        if viewModel.taggedSeconds > 0 {
            parts.append("\(viewModel.durationText(viewModel.taggedSeconds)) on tasks")
        }
        if viewModel.untaggedSeconds > 0 {
            parts.append("\(viewModel.durationText(viewModel.untaggedSeconds)) without a task")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Sessions Panel

    private func sessionsPanel(_ summary: TaskSummary) -> some View {
        let sessions = viewModel.selectedSessions
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SectionHeader(title: "Sessions behind", theme: theme, scale: 1.2)
                Text(summary.title)
                    .font(theme.currentFont.font(size: 12, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleSelection(summary.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(theme.currentFont.font(size: 10, weight: .semibold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect()
                .help("Close")
            }

            Text(viewModel.detailText(for: summary))
                .font(theme.currentFont.font(size: 10.5, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)

            if summary.isUntagged {
                untaggedNote
            }

            if !sessions.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            SessionRow(session: session, theme: theme, scale: 1.2)
                                .contextMenu {
                                    SessionTaskMenu(
                                        session: session,
                                        tasks: viewModel.tasks,
                                        menuTitle: viewModel.menuTitle(for:),
                                        onAssign: viewModel.assign(_:to:)
                                    )
                                }
                            if index < sessions.count - 1 {
                                Divider().background(theme.colors.ringTrack)
                            }
                        }
                    }
                    .padding(.trailing, 6)
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(theme, radius: 10)
    }

    private var untaggedNote: some View {
        HStack(spacing: 12) {
            Text("Focus recorded without a task, such as sessions from before tasks existed.")
                .font(theme.currentFont.font(size: 10.5))
                .foregroundColor(theme.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if viewModel.hasTasks {
                Menu {
                    ForEach(viewModel.tasks) { task in
                        Button(viewModel.menuTitle(for: task)) { pendingAssignment = task }
                    }
                } label: {
                    actionLabel("Assign all to a task…", icon: "arrow.right.circle")
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .hoverEffect()
            } else {
                Button(action: onShowTasks) {
                    actionLabel("Create a task first", icon: "plus.circle")
                }
                .buttonStyle(.plain)
                .hoverEffect()
            }
        }
    }

    private func actionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
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

    // MARK: - Empty

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

// MARK: - Task Card

/// One task: its all-time total as a number and as hour blocks, its session count,
/// and when it was created and finished (or last worked on).
private struct TaskCard: View {
    let summary: TaskSummary
    @ObservedObject var viewModel: TaskAnalyticsViewModel
    let isCurrent: Bool
    let isSelected: Bool
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(summary.title)
                    .font(theme.currentFont.font(size: 13, weight: .semibold))
                    .foregroundColor(summary.isDone || summary.isUntagged ? theme.colors.textSecondary : theme.colors.text)
                    .lineLimit(2)
                Spacer(minLength: 6)
                if isCurrent {
                    badge("CURRENT", color: theme.colors.accent)
                } else if summary.isDone {
                    badge("DONE", color: theme.colors.textSecondary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                Text(summary.sessions > 0 ? viewModel.durationText(summary.totalSeconds) : "—")
                    .font(theme.currentFont.font(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(theme.colors.text)
                    .contentTransition(.numericText())
                Spacer()
                Text("\(summary.sessions) session\(summary.sessions == 1 ? "" : "s")")
                    .font(theme.currentFont.font(size: 10, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
            }

            HourBlocks(value: viewModel.blocks(for: summary), color: blockColor, theme: theme)

            Spacer(minLength: 0)

            Text(viewModel.datesText(for: summary))
                .font(theme.currentFont.font(size: 9.5, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(border)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: action)
        .hoverEffect()
        .help(isSelected ? "Hide the sessions behind this total" : "Show the sessions behind this total")
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: 10)
        if isSelected {
            shape.stroke(theme.colors.accent, lineWidth: 1.5)
        } else if summary.isUntagged {
            shape.stroke(theme.colors.textSecondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        } else {
            shape.stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var blockColor: Color {
        if summary.isUntagged { return theme.colors.textSecondary.opacity(0.55) }
        return summary.isDone ? theme.colors.accent.opacity(0.5) : theme.colors.accent
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(theme.currentFont.font(size: 8, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .fixedSize()
    }
}

// MARK: - Hour Blocks

/// A total drawn as blocks: full blocks for whole units, the last one filled from
/// the bottom by the remaining fraction. Wraps to as many rows as it needs.
private struct HourBlocks: View {
    /// Total in blocks, e.g. 6.75.
    let value: Double
    let color: Color
    @ObservedObject var theme: ThemeManager

    private let size: CGFloat = 10
    private let spacing: CGFloat = 3

    var body: some View {
        let full = Int(value)
        let remainder = value - Double(full)
        let count = full + (remainder >= 0.02 ? 1 : 0)

        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: size, maximum: size), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            if count == 0 {
                RoundedRectangle(cornerRadius: 2.5)
                    .stroke(theme.colors.ringTrack, lineWidth: 1)
                    .frame(width: size, height: size)
            }
            ForEach(0..<count, id: \.self) { index in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(theme.colors.ringTrack)
                    Rectangle()
                        .fill(color)
                        .frame(height: size * (index < full ? 1 : remainder))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 2.5))
            }
        }
    }
}

// MARK: - Session Task Menu

/// Context menu section moving one focus session to another task, or off any task.
/// Done tasks and tasks sharing a title show their creation day.
struct SessionTaskMenu: View {
    let session: StatsSessionItem
    let tasks: [TaskItem]
    let menuTitle: (TaskItem) -> String
    let onAssign: (StatsSessionItem, UUID?) -> Void

    var body: some View {
        if session.isFocus && !tasks.isEmpty {
            Menu("Task") {
                item("No Task", isOn: session.taskID == nil) { onAssign(session, nil) }
                Divider()
                ForEach(tasks) { task in
                    item(menuTitle(task), isOn: session.taskID == task.id) { onAssign(session, task.id) }
                }
            }
        }
    }

    private func item(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isOn {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
