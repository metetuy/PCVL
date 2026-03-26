import SwiftUI

enum PopoverTab {
    case timer
    case stats
    case settings
}

struct PopoverView: View {
    @StateObject private var viewModel = TimerViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var statsManager = StatisticsManager()
    @State private var selectedTab: PopoverTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton(tab: .timer, icon: "timer", label: "Timer")
                tabButton(tab: .stats, icon: "chart.bar", label: "Stats")
                tabButton(tab: .settings, icon: "gear", label: "Settings")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Divider()
                .padding(.top, 4)

            // Content
            Group {
                switch selectedTab {
                case .timer:
                    TimerContentView(viewModel: viewModel, theme: themeManager)
                case .stats:
                    StatsView(statsManager: statsManager, theme: themeManager)
                case .settings:
                    SettingsView(viewModel: viewModel, theme: themeManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 320, height: 420)
        .background(themeManager.colors.background)
        .onAppear {
            viewModel.setStatisticsManager(statsManager)
        }
    }

    private func tabButton(tab: PopoverTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundColor(selectedTab == tab ? themeManager.colors.accent : themeManager.colors.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct TimerContentView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Phase indicator
            HStack(spacing: 12) {
                phaseChip(phase: .work, current: viewModel.phase)
                phaseChip(phase: .shortBreak, current: viewModel.phase)
            }
            .padding(.top, 16)

            // Mode toggle
            Button {
                viewModel.toggleMode()
            } label: {
                Text(viewModel.engine.mode == .countdown ? "Pomodoro" : "Stopwatch")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(theme.colors.surface)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Timer ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(theme.colors.surface, lineWidth: 8)
                    .frame(width: 160, height: 160)

                // Progress ring (countdown only)
                if viewModel.engine.mode == .countdown {
                    Circle()
                        .trim(from: 0, to: viewModel.engine.progress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.engine.progress)
                }

                // Time display
                VStack(spacing: 4) {
                    Text(viewModel.engine.formattedTime)
                        .font(.system(size: 42, weight: .light, design: .monospaced))
                        .foregroundColor(theme.colors.text)

                    if viewModel.engine.mode == .countdown {
                        Text(viewModel.phase.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
            }

            Spacer()

            // Controls
            HStack(spacing: 20) {
                // Reset
                Button {
                    viewModel.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isIdle)

                // Play/Pause
                Button {
                    if viewModel.isRunning {
                        viewModel.pause()
                    } else {
                        viewModel.start()
                    }
                } label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundColor(theme.colors.background)
                        .frame(width: 56, height: 56)
                        .background(theme.colors.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Skip
                Button {
                    viewModel.skipPhase()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.engine.mode == .stopwatch)
            }
            .padding(.bottom, 16)

            // Session counter
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.sessionsCompleted % 4
                              ? theme.colors.accent
                              : theme.colors.surface)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 12)
        }
    }

    private var ringColor: Color {
        viewModel.phase == .work ? theme.colors.timerRing : theme.colors.breakRing
    }

    private func phaseChip(phase: PomodoroPhase, current: PomodoroPhase) -> some View {
        Text(phase.rawValue)
            .font(.system(size: 12, weight: phase == current ? .semibold : .regular))
            .foregroundColor(phase == current ? theme.colors.accent : theme.colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(phase == current ? theme.colors.accent.opacity(0.15) : Color.clear)
            .clipShape(Capsule())
    }
}
