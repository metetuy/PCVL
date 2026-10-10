import SwiftUI

// MARK: - Focus Screen

/// Distraction-free timer for the window: the time, one row of controls, and a
/// quiet footer. Scales with the window, including native full screen.
struct FocusScreen: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    @ObservedObject var summary: StatsSummaryViewModel

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let timeSize = min(size.width * 0.19, size.height * 0.30)
            let scale = min(max(min(size.width / 300, size.height / 190) * 0.32, 1.3), 2.0)

            VStack(spacing: 0) {
                TimerModeToggle(viewModel: viewModel, theme: theme, scale: 1.3)
                    .padding(.top, 16)

                Spacer()

                Text(viewModel.modeLabel)
                    .font(theme.currentFont.font(size: 9 * scale, weight: .semibold))
                    .tracking(3 * scale)
                    .foregroundColor(theme.colors.textSecondary)

                Text(viewModel.engine.formattedTime)
                    .font(theme.timerFont(size: timeSize, weight: .thin))
                    .foregroundColor(theme.colors.text)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .timerDurationScroll(viewModel)
                    .help(viewModel.editableCountdownDuration != nil ? "Scroll to adjust the duration" : "")

                TimerProgressLine(viewModel: viewModel, theme: theme, height: 4)
                    .frame(maxWidth: min(size.width * 0.5, 640))
                    .padding(.top, 4)

                controls(scale: scale)
                    .padding(.top, 36)

                Spacer()

                footer
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Controls

    private func controls(scale: CGFloat) -> some View {
        TimerControlRow(viewModel: viewModel, theme: theme, scale: scale, spacing: 22 * scale) {
            TimerPrimaryButton(viewModel: viewModel, theme: theme, scale: scale)
                .keyboardShortcut(.space, modifiers: [])
                .help("Start / pause (Space)")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(summary.todaySummaryText(inProgressSeconds: viewModel.inProgressFocusSeconds))
            Spacer()
            if let next = viewModel.nextPhaseLabel {
                Text(next)
            }
        }
        .font(theme.currentFont.font(size: 11, weight: .medium))
        .foregroundColor(theme.colors.textSecondary)
        .lineLimit(1)
    }
}
