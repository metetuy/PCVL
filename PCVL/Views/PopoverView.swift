import SwiftUI

// MARK: - Tab Enum

enum AppTab {
    case timer
    case stats
    case settings
}

// MARK: - Popover View (Shell)

struct PopoverView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var themeManager: ThemeManager
    @ObservedObject var statsManager: StatisticsManager
    var onToggleFullscreen: () -> Void

    @State private var selectedTab: AppTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar
            Divider().background(themeManager.colors.ringTrack)

            // Content
            ZStack {
                switch selectedTab {
                case .timer:
                    TimerView(
                        viewModel: viewModel,
                        theme: themeManager,
                        onToggleFullscreen: onToggleFullscreen
                    )
                case .stats:
                    StatsView(
                        statsManager: statsManager,
                        theme: themeManager
                    )
                case .settings:
                    SettingsView(
                        viewModel: viewModel,
                        theme: themeManager,
                        statsManager: statsManager
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 280, height: 140)
        .background(themeManager.colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(tab: .timer, icon: "timer")
            tabButton(tab: .stats, icon: "chart.bar")
            tabButton(tab: .settings, icon: "gear")
        }
        .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
        .padding(.horizontal, 8)
    }

    private func tabButton(tab: AppTab, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(
                    selectedTab == tab
                        ? themeManager.colors.accent
                        : themeManager.colors.textSecondary
                )
        }
        .buttonStyle(.plain)
    }
}
