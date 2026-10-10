import SwiftUI

// MARK: - Timer View

/// Compact timer for the menu bar panel. The window's focus screen reuses the same
/// controls at a larger scale (see FocusScreen).
struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // Top row: mode toggle + label
            HStack {
                TimerModeToggle(viewModel: viewModel, theme: theme)
                Spacer()
                Text(viewModel.modeLabel)
                    .font(theme.currentFont.font(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Center: reset | time + progress line | skip
            HStack(spacing: 12) {
                TimerCircleButton(icon: "arrow.counterclockwise", theme: theme) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.reset()
                    }
                }
                .disabled(viewModel.isIdle)
                .opacity(viewModel.isIdle ? 0.3 : 1)
                .help("Reset")

                timerDisplay

                TimerCircleButton(icon: "forward.end", iconSize: 10, theme: theme) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.skipPhase()
                    }
                }
                .disabled(!viewModel.canSkipPhase)
                .opacity(viewModel.canSkipPhase ? 1 : 0.3)
                .help(viewModel.isBreak ? "Skip to focus" : "Skip to break")
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
                .foregroundColor(theme.colors.text)
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
