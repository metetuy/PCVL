import SwiftUI

// MARK: - Timer View

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var onToggleFullscreen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top row: mode toggle + label
            HStack {
                modeToggle
                Spacer()
                Text(viewModel.modeLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Center: reset | time + progress line | fullscreen
            HStack(spacing: 12) {
                // Reset button
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.reset()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isIdle)
                .opacity(viewModel.isIdle ? 0.3 : 1)

                // Timer display — clickable
                timerDisplay
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if viewModel.isCompleted {
                                if viewModel.isBreak {
                                    viewModel.skipToWork()
                                } else {
                                    viewModel.skipToBreak()
                                }
                            } else if viewModel.isRunning {
                                viewModel.pause()
                            } else {
                                viewModel.start()
                            }
                        }
                    }

                // Fullscreen button
                Button {
                    onToggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.mode = mode
                    }
                } label: {
                    Text(mode == .countDown ? "Timer" : "Stopwatch")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(viewModel.mode == mode ? theme.colors.accent : theme.colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.mode == mode
                                ? theme.colors.accent.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIdle)
                .opacity(viewModel.isIdle ? 1 : (viewModel.mode == mode ? 1 : 0.4))
            }
        }
        .padding(2)
        .background(theme.colors.surface)
        .clipShape(Capsule())
    }

    // MARK: - Timer Display (time + progress line)

    private var timerDisplay: some View {
        VStack(spacing: 6) {
            // Time text
            Text(viewModel.engine.formattedTime)
                .font(.system(size: 32, weight: .thin, design: .monospaced))
                .foregroundColor(theme.colors.text)
                .contentTransition(.numericText())

            // Progress line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(theme.colors.ringTrack)
                        .frame(height: 3)

                    // Fill (countdown only)
                    if viewModel.mode == .countDown {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(viewModel.isBreak ? theme.colors.breakRing : theme.colors.timerRing)
                            .frame(width: geo.size.width * viewModel.engine.progress, height: 3)
                            .animation(.linear(duration: 0.3), value: viewModel.engine.progress)
                    }
                }
            }
            .frame(height: 3)

            // Tap hint
            if viewModel.isIdle {
                Text("tap to start")
                    .font(.system(size: 7))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.5))
            } else if viewModel.isPaused {
                Text("tap to resume")
                    .font(.system(size: 7))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.5))
            } else {
                Text(" ")
                    .font(.system(size: 7))
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}
