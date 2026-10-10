import SwiftUI

// MARK: - Main Window View

/// Shell of the desktop window: a collapsible sidebar, a top bar with the sidebar,
/// full screen and panel controls, and the selected screen. Each screen lives in
/// its own file.
struct MainWindowView: View {
    @ObservedObject var state: WindowState
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    let statsManager: StatisticsManager
    let analytics: AnalyticsViewModel
    let onToggleFullScreen: () -> Void
    let onSwitchToPanel: () -> Void
    let onClose: () -> Void

    static let sidebarWidth: CGFloat = 196
    /// Wide enough to clear the traffic-light buttons in windowed mode.
    static let collapsedSidebarWidth: CGFloat = 72
    /// Matches the compact title bar so the top bar lines up with the traffic lights.
    static let topBarHeight: CGFloat = 38

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: state.isSidebarCollapsed ? Self.collapsedSidebarWidth : Self.sidebarWidth)

            Rectangle()
                .fill(theme.colors.ringTrack)
                .frame(width: 0.5)

            VStack(spacing: 0) {
                topBar
                    .frame(height: Self.topBarHeight)
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // The top bar sits in the transparent title bar area.
        .ignoresSafeArea(edges: .top)
        .frame(minWidth: MainWindowController.minimumSize.width, minHeight: MainWindowController.minimumSize.height)
        .background(ThemedBackground(theme: theme, radius: 900).ignoresSafeArea())
        .background(closeShortcut)
    }

    @ViewBuilder
    private var screen: some View {
        switch state.section {
        case .focus:
            FocusScreen(viewModel: timerViewModel, theme: theme)
        case .analytics:
            AnalyticsScreen(viewModel: analytics, theme: theme)
        case .settings:
            SettingsScreen(timerViewModel: timerViewModel, theme: theme, statsManager: statsManager)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            WindowBarButton(
                icon: "sidebar.left",
                help: state.isSidebarCollapsed ? "Show sidebar labels" : "Collapse sidebar to icons",
                theme: theme
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.toggleSidebar()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Spacer()

            WindowBarButton(
                icon: state.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                help: state.isFullScreen ? "Exit full screen" : "Enter full screen",
                theme: theme,
                action: onToggleFullScreen
            )
            .keyboardShortcut("f", modifiers: [.command, .control])

            WindowBarButton(
                icon: "menubar.arrow.up.rectangle",
                help: "Switch to the menu bar panel",
                theme: theme,
                action: onSwitchToPanel
            )
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        let collapsed = state.isSidebarCollapsed

        return VStack(alignment: collapsed ? .center : .leading, spacing: 4) {
            if !collapsed {
                Text("PCVL")
                    .font(theme.currentFont.font(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(theme.colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }

            ForEach(Array(WindowSection.allCases.enumerated()), id: \.element) { index, section in
                SidebarItem(
                    section: section,
                    shortcut: Character("\(index + 1)"),
                    isSelected: state.section == section,
                    isCollapsed: collapsed,
                    theme: theme
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.section = section
                    }
                }
            }

            Spacer()

            if !timerViewModel.isIdle && state.section != .focus {
                sessionStatus(collapsed: collapsed)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, collapsed ? 10 : 12)
        // Clears the traffic lights (windowed) / keeps the same rhythm (full screen).
        .padding(.top, Self.topBarHeight + 14)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.15), value: timerViewModel.isIdle)
    }

    /// Live timer readout while another section is shown; clicking returns to Focus.
    private func sessionStatus(collapsed: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                state.section = .focus
            }
        } label: {
            Group {
                if collapsed {
                    VStack(spacing: 5) {
                        Text(timerViewModel.engine.formattedTime)
                            .font(theme.currentFont.font(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.colors.text)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        TimerProgressLine(viewModel: timerViewModel, theme: theme, height: 2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(timerViewModel.modeLabel)
                                .font(theme.currentFont.font(size: 9, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(theme.colors.textSecondary)
                            Spacer()
                            Text(timerViewModel.engine.formattedTime)
                                .font(theme.currentFont.font(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.colors.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        TimerProgressLine(viewModel: timerViewModel, theme: theme, height: 2)
                    }
                    .padding(10)
                }
            }
            .cardBackground(theme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .help("\(timerViewModel.modeLabel.capitalized) session — back to Focus")
    }

    /// The app has no main menu, so ⌘W is provided here.
    private var closeShortcut: some View {
        Button("Close", action: onClose)
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
    }
}

// MARK: - Window Bar Button

/// Round icon button in the window's top bar.
private struct WindowBarButton: View {
    let icon: String
    let help: String
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 11, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 26, height: 26)
                .background(theme.colors.surface)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .hoverEffect()
        .help(help)
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: WindowSection
    let shortcut: Character
    let isSelected: Bool
    let isCollapsed: Bool
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(theme.currentFont.font(size: isCollapsed ? 15 : 13))
                    .frame(width: 18)
                if !isCollapsed {
                    Text(section.title)
                        .font(theme.currentFont.font(size: 13, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer()
                    Text("⌘\(String(shortcut))")
                        .font(theme.currentFont.font(size: 10))
                        .foregroundColor(theme.colors.textSecondary.opacity(0.7))
                }
            }
            .foregroundColor(isSelected ? theme.colors.accent : theme.colors.text)
            .padding(.horizontal, isCollapsed ? 0 : 12)
            .padding(.vertical, isCollapsed ? 10 : 8)
            .frame(maxWidth: isCollapsed ? 44 : .infinity)
            .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
        .help(isCollapsed ? "\(section.title) (⌘\(String(shortcut)))" : "")
    }
}
