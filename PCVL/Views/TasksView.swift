import SwiftUI

// MARK: - Tasks View

/// Open tasks for the menu bar panel: add one, pick the current one, check off.
/// Done tasks and the full list live in the window (TasksScreen).
struct TasksView: View {
    @ObservedObject var viewModel: TasksViewModel
    /// Not observed here: only the current task's live total depends on the timer.
    let timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    @State private var newTitle = ""
    @State private var editingID: UUID?
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                addField

                if viewModel.openTasks.isEmpty {
                    Text(viewModel.hasTasks
                         ? "All done. Add a task to keep tracking your focus."
                         : "Add what you're working on. Focus sessions count toward the current task.")
                        .font(theme.currentFont.font(size: 10))
                        .foregroundColor(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                } else {
                    TaskList(
                        tasks: viewModel.openTasks,
                        viewModel: viewModel,
                        timerViewModel: timerViewModel,
                        theme: theme,
                        isCompact: true,
                        editingID: $editingID
                    )
                }

                if let footer {
                    Text(footer)
                        .font(theme.currentFont.font(size: 9))
                        .foregroundColor(theme.colors.textSecondary)
                        .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            // Leaves room for the panel's expand handle.
            .padding(.bottom, 24)
        }
    }

    private var footer: String? {
        if viewModel.isSelectionLocked {
            return "The current task changes once this focus session ends."
        }
        let done = viewModel.doneTasks.count
        return done > 0 ? "\(done) done · expand to see all" : nil
    }

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(theme.currentFont.font(size: 10, weight: .semibold))
                .foregroundColor(theme.colors.accent)
            TextField("Add a task", text: $newTitle)
                .textFieldStyle(.plain)
                .font(theme.currentFont.font(size: 11))
                .foregroundColor(theme.colors.text)
                .focused($isAddFieldFocused)
                .onSubmit {
                    viewModel.addTask(newTitle)
                    newTitle = ""
                    isAddFieldFocused = true
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .cardBackground(theme)
    }
}
