import SwiftUI

// Settings building blocks shared by the panel's settings tab and the window's
// settings screen.

// MARK: - Reset Confirmation

extension View {
    /// The "Reset Statistics" confirmation, worded once in `AppSettings`.
    func resetStatisticsAlert(isPresented: Binding<Bool>, settings: AppSettings) -> some View {
        alert(AppSettings.resetTitle, isPresented: isPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { settings.resetStatistics() }
        } message: {
            Text(AppSettings.resetMessage)
        }
    }
}

// MARK: - Duration Stepper

/// − value + stepper for a timer duration. Observes the timer on its own, so the
/// surrounding settings screen does not re-render on every tick of a running timer.
struct DurationStepper: View {
    let duration: TimerViewModel.AdjustableDuration
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 10 * scale) {
            stepButton(icon: "minus", delta: -duration.stepMinutes)
            Text("\(viewModel.durationMinutes(for: duration)) min")
                .font(theme.currentFont.font(size: 11 * scale, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.colors.text)
                .frame(minWidth: 44 * scale)
            stepButton(icon: "plus", delta: duration.stepMinutes)
        }
        .disabled(!viewModel.isIdle)
        .opacity(viewModel.isIdle ? 1 : 0.4)
    }

    private func stepButton(icon: String, delta: Int) -> some View {
        Button {
            viewModel.adjustDuration(duration, byMinutes: delta)
        } label: {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 9 * scale, weight: .bold))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 19 * scale, height: 19 * scale)
                .background(theme.colors.background)
                .clipShape(Circle())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .hoverEffect()
    }
}

/// Shows `text` only while the timer is running or paused (durations are locked then).
struct DurationLockedNote: View {
    let text: String
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    var body: some View {
        if !viewModel.isIdle {
            Text(text)
                .font(theme.currentFont.font(size: 11))
                .foregroundColor(theme.colors.textSecondary)
        }
    }
}
