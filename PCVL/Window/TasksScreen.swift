import SwiftUI

// MARK: - Tasks Screen

/// Tasks to spend focus sessions on: add, pick the current one, check off. Each
/// task shows the focus time and sessions recorded toward it.
struct TasksScreen: View {
    @ObservedObject var viewModel: TasksViewModel
    /// Not observed here: only the current task's live total depends on the timer.
    let timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    @State private var newTitle = ""
    @State private var editingID: UUID?
    @State private var showsDone = true
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tasks")
                        .font(theme.currentFont.font(size: 20, weight: .semibold))
                        .foregroundColor(theme.colors.text)
                    Text(subtitle)
                        .font(theme.currentFont.font(size: 12))
                        .foregroundColor(theme.colors.textSecondary)
                }

                addField

                if viewModel.hasTasks {
                    openSection
                    if !viewModel.doneTasks.isEmpty {
                        doneSection
                    }
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var subtitle: String {
        if viewModel.isSelectionLocked {
            return "A focus session is running. It counts toward its task until it ends."
        }
        return "Focus sessions count toward the current task. Click a task to make it current."
    }

    // MARK: - Add

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(theme.currentFont.font(size: 12, weight: .semibold))
                .foregroundColor(theme.colors.accent)
            TextField("Add a task", text: $newTitle)
                .textFieldStyle(.plain)
                .font(theme.currentFont.font(size: 13))
                .foregroundColor(theme.colors.text)
                .focused($isAddFieldFocused)
                .onSubmit {
                    viewModel.addTask(newTitle)
                    newTitle = ""
                    isAddFieldFocused = true
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cardBackground(theme, radius: 10)
    }

    // MARK: - Lists

    private var openSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "To do · \(viewModel.openTasks.count)", theme: theme, scale: 1.2)
            if viewModel.openTasks.isEmpty {
                Text("All done. Add a task to keep tracking your focus.")
                    .font(theme.currentFont.font(size: 12))
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(.vertical, 4)
            } else {
                taskList(viewModel.openTasks)
            }
        }
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showsDone.toggle() }
            } label: {
                HStack(spacing: 6) {
                    SectionHeader(title: "Done · \(viewModel.doneTasks.count)", theme: theme, scale: 1.2)
                    Image(systemName: "chevron.right")
                        .font(theme.currentFont.font(size: 8, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .rotationEffect(.degrees(showsDone ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect()

            if showsDone {
                taskList(viewModel.doneTasks)
            }
        }
    }

    private func taskList(_ tasks: [TaskItem]) -> some View {
        TaskList(
            tasks: tasks,
            viewModel: viewModel,
            timerViewModel: timerViewModel,
            theme: theme,
            scale: 1.2,
            editingID: $editingID
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(theme.currentFont.font(size: 28, weight: .light))
                .foregroundColor(theme.colors.textSecondary)
            Text("No tasks yet")
                .font(theme.currentFont.font(size: 14, weight: .semibold))
                .foregroundColor(theme.colors.text)
            Text("Add what you're working on. Every focus session then counts toward the current task.")
                .font(theme.currentFont.font(size: 12))
                .foregroundColor(theme.colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
