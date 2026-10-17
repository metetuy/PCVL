import SwiftUI

// MARK: - Timer View

/// Compact timer for the menu bar panel. The window's focus screen reuses the same
/// controls at a larger scale (see FocusScreen).
struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    @ObservedObject var tasks: TasksViewModel
    let onManageTasks: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top row: mode toggle + current task (once there are tasks) + label
            HStack(spacing: 6) {
                TimerModeToggle(viewModel: viewModel, theme: theme)
                    .fixedSize()
                Spacer(minLength: 4)
                if tasks.hasTasks {
                    TaskPicker(viewModel: tasks, theme: theme, maxTitleWidth: 42, onManageTasks: onManageTasks)
                }
                Text(viewModel.modeLabel)
                    .font(theme.currentFont.font(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.colors.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Center: reset | time + progress line | skip
            TimerControlRow(viewModel: viewModel, theme: theme) {
                timerDisplay
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Timer Display (time + progress line + button)

    private var timerDisplay: some View {
        VStack(spacing: 6) {
            Text(viewModel.engine.formattedTime)
                .font(theme.timerFont(size: 36, weight: .thin))
                .foregroundColor(theme.colors.focusText)
                .contentTransition(.numericText())

            TimerProgressLine(viewModel: viewModel, theme: theme)

            TimerPrimaryButton(viewModel: viewModel, theme: theme)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .timerDurationScroll(viewModel)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.performPrimaryAction()
            }
        }
    }
}
