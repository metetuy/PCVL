import SwiftUI

// MARK: - Timer View

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    var onToggleFullscreen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle — compact, top-left
            HStack {
                modeToggle
                Spacer()
                // Mode label
                Text(viewModel.modeLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // Main content — horizontal: reset | ring | fullscreen
            HStack(spacing: 16) {
                // Reset button — left side
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.reset()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isIdle)
                .opacity(viewModel.isIdle ? 0.3 : 1)

                // Timer ring — clickable to start/pause
                timerRing
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

                // Fullscreen button — right side
                Button {
                    onToggleFullscreen()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(theme.colors.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

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

    // MARK: - Timer Ring

    private var timerRing: some View {
        let ringSize: CGFloat = 150

        return ZStack {
            // Track
            Circle()
                .stroke(theme.colors.ringTrack, lineWidth: 3)
                .frame(width: ringSize, height: ringSize)

            // Progress fill (countdown only)
            if viewModel.mode == .countDown {
                Circle()
                    .trim(from: 0, to: viewModel.engine.progress)
                    .stroke(
                        viewModel.isBreak ? theme.colors.breakRing : theme.colors.timerRing,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: viewModel.engine.progress)
            }

            // Time display
            VStack(spacing: 2) {
                Text(viewModel.engine.formattedTime)
                    .font(.system(size: ringSize * 0.22, weight: .thin, design: .monospaced))
                    .foregroundColor(theme.colors.text)
                    .contentTransition(.numericText())

                // Tap hint when idle
                if viewModel.isIdle {
                    Text("tap to start")
                        .font(.system(size: 8))
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))
                } else if viewModel.isPaused {
                    Text("tap to resume")
                        .font(.system(size: 8))
                        .foregroundColor(theme.colors.textSecondary.opacity(0.6))
                }
            }
        }
        .contentShape(Circle())
    }
}
