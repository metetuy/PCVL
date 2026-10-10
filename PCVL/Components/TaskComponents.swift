import SwiftUI

// Task building blocks shared by the menu bar panel and the window.
// `scale` = 1 is the compact panel size.

// MARK: - Task Picker

/// Chip showing the current task; its menu picks another one. Disabled while a focus
/// session is in progress, since that session counts toward the task it started with.
struct TaskPicker: View {
    @ObservedObject var viewModel: TasksViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var maxTitleWidth: CGFloat = 220
    /// Opens the window's tasks screen.
    let onManageTasks: () -> Void

    var body: some View {
        Menu {
            Picker("Current task", selection: selection) {
                Text("No Task").tag(UUID?.none)
                ForEach(viewModel.openTasks) { task in
                    Text(task.title).tag(UUID?.some(task.id))
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            Divider()
            Button("Manage Tasks…", action: onManageTasks)
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(viewModel.isSelectionLocked)
        .hoverEffect()
        .help(viewModel.isSelectionLocked
              ? "This session counts toward its task until it ends"
              : "Choose the task this session counts toward")
    }

    private var selection: Binding<UUID?> {
        Binding(get: { viewModel.activeTaskID }, set: { viewModel.select($0) })
    }

    private var label: some View {
        let title = viewModel.activeTask?.title
        return HStack(spacing: 4 * scale) {
            Image(systemName: title == nil ? "circle.dashed" : "checklist")
                .font(theme.currentFont.font(size: 8 * scale, weight: .semibold))
            Text(title ?? "No task")
                .font(theme.currentFont.font(size: 9 * scale, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: maxTitleWidth * scale, alignment: .leading)
            if !viewModel.isSelectionLocked {
                Image(systemName: "chevron.down")
                    .font(theme.currentFont.font(size: 6 * scale, weight: .bold))
            }
        }
        .foregroundColor(title == nil ? theme.colors.textSecondary : theme.colors.accent)
        .padding(.horizontal, 7 * scale)
        .padding(.vertical, 3 * scale)
        .background((title == nil ? theme.colors.textSecondary : theme.colors.accent).opacity(0.12))
        .clipShape(Capsule())
        .contentShape(Capsule())
    }
}

// MARK: - Task List

/// Card of task rows, used by the window's tasks screen and the panel's tasks tab.
struct TaskList: View {
    let tasks: [TaskItem]
    @ObservedObject var viewModel: TasksViewModel
    /// Not observed here: only the current task's live total depends on the timer.
    let timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var isCompact = false
    @Binding var editingID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider().background(theme.colors.ringTrack)
                }
                TaskRow(
                    task: task,
                    isCurrent: task.id == viewModel.activeTaskID,
                    canSelect: !task.isDone && !viewModel.isSelectionLocked,
                    timerViewModel: timerViewModel,
                    theme: theme,
                    scale: scale,
                    isCompact: isCompact,
                    isEditing: Binding(
                        get: { editingID == task.id },
                        set: { editingID = $0 ? task.id : nil }
                    ),
                    onSelect: { viewModel.select(task.id) },
                    onToggleDone: {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleDone(task.id) }
                    },
                    onRename: { viewModel.rename(task.id, to: $0) },
                    onDelete: {
                        withAnimation(.easeInOut(duration: 0.2)) { viewModel.delete(task.id) }
                    }
                )
            }
        }
        .cardBackground(theme, radius: 8 * scale)
    }
}

// MARK: - Task Row

/// One task: check box, title (inline rename), totals, and the current marker.
/// Clicking an open task makes it current. Compact rows fit everything on one line
/// with the time trailing, for the panel.
struct TaskRow: View {
    let task: TaskItem
    let isCurrent: Bool
    let canSelect: Bool
    let timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var isCompact = false
    @Binding var isEditing: Bool
    let onSelect: () -> Void
    let onToggleDone: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var draftTitle = ""
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: (isCompact ? 8 : 10) * scale) {
            checkBox

            if isCompact {
                title
                Spacer(minLength: 6 * scale)
                trailingSlot
            } else {
                VStack(alignment: .leading, spacing: 3 * scale) {
                    title
                    totals
                }
                Spacer(minLength: 8 * scale)
                if isCurrent {
                    currentBadge
                }
            }

            if !isCompact {
                if isEditing {
                    editActions
                } else {
                    actions
                        .opacity(showsActions ? 1 : 0)
                        .allowsHitTesting(showsActions)
                }
            }
        }
        .padding(.horizontal, (isCompact ? 10 : 11.5) * scale)
        .padding(.vertical, (isCompact ? 6 : 8) * scale)
        .background(isCurrent ? theme.colors.accent.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if canSelect && !isCurrent && !isEditing { onSelect() }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            if canSelect && !isCurrent {
                Button("Make Current", action: onSelect)
            }
            Button(task.isDone ? "Mark as Not Done" : "Mark as Done", action: onToggleDone)
            Button("Rename", action: startEditing)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .help(canSelect && !isCurrent ? "Make this the current task" : "")
    }

    private var showsActions: Bool { isHovering && !isEditing }

    /// Compact rows: the time, with the actions drawn over it while hovered or
    /// renaming. An overlay never changes the row's size, and the slot is always
    /// wide enough for the two buttons, so hovering moves nothing.
    private var trailingSlot: some View {
        totals
            .opacity(isEditing || showsActions ? 0 : 1)
            .frame(minWidth: 38 * scale, alignment: .trailing)
            .overlay(alignment: .trailing) {
                if isEditing {
                    editActions
                } else if showsActions {
                    actions
                }
            }
    }

    /// Rename and delete, shown while the row is hovered.
    private var actions: some View {
        HStack(spacing: 2 * scale) {
            actionButton(icon: "pencil", help: "Rename", action: startEditing)
            actionButton(icon: "trash", help: "Delete task (its sessions stay in your statistics)", action: onDelete)
        }
    }

    /// Save and cancel while renaming (Return and Escape do the same).
    private var editActions: some View {
        HStack(spacing: 2 * scale) {
            actionButton(icon: "checkmark", help: "Save (Return)", color: theme.colors.accent, action: commitEditing)
            actionButton(icon: "xmark", help: "Cancel (Esc)", action: cancelEditing)
        }
    }

    private func actionButton(
        icon: String,
        help: String,
        color: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 9.5 * scale, weight: .medium))
                .foregroundColor(color ?? theme.colors.textSecondary)
                .frame(width: 18 * scale, height: 18 * scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .help(help)
    }

    private var currentBadge: some View {
        Text("CURRENT")
            .font(theme.currentFont.font(size: 7.5 * scale, weight: .semibold))
            .tracking(1)
            .foregroundColor(theme.colors.accent)
            .padding(.horizontal, 6 * scale)
            .padding(.vertical, 2.5 * scale)
            .background(theme.colors.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    private var checkBox: some View {
        Button(action: onToggleDone) {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : (isCurrent ? "largecircle.fill.circle" : "circle"))
                .font(theme.currentFont.font(size: 13 * scale))
                .foregroundColor(task.isDone || isCurrent ? theme.colors.accent : theme.colors.textSecondary)
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .help(task.isDone ? "Mark as not done" : "Mark as done")
    }

    @ViewBuilder
    private var title: some View {
        if isEditing {
            TextField("Task", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(theme.currentFont.font(size: 11 * scale, weight: .medium))
                .foregroundColor(theme.colors.text)
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 2 * scale)
                .background(theme.colors.background.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4 * scale))
                .overlay(RoundedRectangle(cornerRadius: 4 * scale).stroke(theme.colors.accent.opacity(0.5), lineWidth: 1))
                // Offsets the padding so the text stays where the title was and the
                // row keeps its height.
                .padding(.horizontal, -5 * scale)
                .padding(.vertical, -2 * scale)
                .focused($isTitleFocused)
                .onAppear {
                    draftTitle = task.title
                    isTitleFocused = true
                }
                .onSubmit(commitEditing)
                .onExitCommand(perform: cancelEditing)
                .onChange(of: isTitleFocused) { _, focused in
                    if !focused { commitEditing() }
                }
        } else {
            Text(task.title)
                .font(theme.currentFont.font(size: 11 * scale, weight: isCurrent ? .semibold : .medium))
                .foregroundColor(task.isDone ? theme.colors.textSecondary : theme.colors.text)
                .strikethrough(task.isDone, color: theme.colors.textSecondary)
                .lineLimit(isCompact ? 1 : 2)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var totals: some View {
        if isCurrent {
            LiveTaskTotals(task: task, viewModel: timerViewModel, theme: theme, scale: scale, isCompact: isCompact)
        } else {
            Text(TasksViewModel.totalsText(seconds: task.focusSeconds, sessions: task.sessions, compact: isCompact))
                .font(theme.currentFont.font(size: 9 * scale, weight: isCompact ? .medium : .regular))
                .foregroundColor(theme.colors.textSecondary)
                .lineLimit(1)
        }
    }

    private func startEditing() {
        draftTitle = task.title
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func commitEditing() {
        guard isEditing else { return }
        onRename(draftTitle)
        isEditing = false
    }
}

// MARK: - Live Task Totals

/// The current task's totals including the focus session in progress. The only
/// part of a task list that observes the timer.
private struct LiveTaskTotals: View {
    let task: TaskItem
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1
    var isCompact = false

    var body: some View {
        let running = viewModel.sessionTaskID == task.id ? viewModel.inProgressFocusSeconds : 0
        HStack(spacing: 5 * scale) {
            if running > 0 {
                Circle()
                    .fill(theme.colors.accent)
                    .frame(width: 4 * scale, height: 4 * scale)
            }
            Text(TasksViewModel.totalsText(seconds: task.focusSeconds + running, sessions: task.sessions, compact: isCompact))
                .contentTransition(.numericText())
            if running > 0 && !isCompact {
                Text("in session")
                    .foregroundColor(theme.colors.accent)
            }
        }
        .font(theme.currentFont.font(size: 9 * scale, weight: isCompact ? .medium : .regular))
        .foregroundColor(theme.colors.textSecondary)
        .lineLimit(1)
        .help(running > 0 ? "Includes the focus session in progress" : "")
    }
}
