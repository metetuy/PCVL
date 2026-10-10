import SwiftUI

// MARK: - Main Window View

/// Shell of the desktop window: a collapsible sidebar, a top bar with the sidebar,
/// full screen and panel controls, and the selected screen. Each screen lives in
/// its own file.
struct MainWindowView: View {
    @ObservedObject var state: WindowState
    /// Not observed: the engine publishes every second, and only the screens and the
    /// sidebar status that show live time observe it themselves.
    let timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    let settings: AppSettings
    let summary: StatsSummaryViewModel
    let analytics: AnalyticsViewModel
    let onToggleFullScreen: () -> Void
    let onSwitchToPanel: () -> Void
    let onClose: () -> Void

    static let sidebarWidth: CGFloat = 196
    /// Wide enough to clear the traffic-light buttons in windowed mode.
    static let collapsedSidebarWidth: CGFloat = 72
    /// Fallback height for the top bar if the window reports no title bar inset.
    static let minimumTopBarHeight: CGFloat = 38

    private var sidebarWidth: CGFloat {
        state.isSidebarCollapsed ? Self.collapsedSidebarWidth : Self.sidebarWidth
    }

    var body: some View {
        // The content respects the title bar's safe area and only the top bar is
        // drawn into it. A screen whose container ignored the safe area would extend
        // its scroll view (a real NSView) up under the top bar and swallow its clicks.
        GeometryReader { geo in
            let titleBarHeight = geo.safeAreaInsets.top
            let topBarHeight = max(titleBarHeight, Self.minimumTopBarHeight)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)

                Rectangle()
                    .fill(theme.colors.ringTrack)
                    .frame(width: 0.5)
                    .ignoresSafeArea(edges: .top)

                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, topBarHeight - titleBarHeight)
            .overlay(alignment: .topLeading) {
                // Shares the title bar with the traffic lights, vertically centered on them.
                topBar
                    .frame(height: topBarHeight)
                    .padding(.leading, sidebarWidth + 0.5)
                    .offset(y: -titleBarHeight)
            }
        }
        .background(ThemedBackground(theme: theme, radius: 900).ignoresSafeArea())
        .background(closeShortcut)
    }

    @ViewBuilder
    private var screen: some View {
        switch state.section {
        case .focus:
            FocusScreen(viewModel: timerViewModel, theme: theme, summary: summary)
        case .analytics:
            AnalyticsScreen(viewModel: analytics, theme: theme)
        case .settings:
            SettingsScreen(timerViewModel: timerViewModel, theme: theme, settings: settings)
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

            if state.section != .focus {
                SidebarSessionStatus(viewModel: timerViewModel, theme: theme, isCollapsed: collapsed) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.section = .focus
                    }
                }
            }
        }
        .padding(.horizontal, collapsed ? 10 : 12)
        .padding(.vertical, 14)
    }

    /// The app has no main menu, so ⌘W is provided here.
    private var closeShortcut: some View {
        Button("Close", action: onClose)
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
    }
}

// MARK: - Sidebar Session Status

/// Live timer readout while another section is shown; clicking returns to Focus.
/// The only part of the shell that observes the timer.
private struct SidebarSessionStatus: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if !viewModel.isIdle {
                button
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.isIdle)
    }

    private var button: some View {
        Button(action: action) {
            Group {
                if isCollapsed {
                    VStack(spacing: 5) {
                        Text(viewModel.engine.formattedTime)
                            .font(theme.currentFont.font(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.colors.text)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        TimerProgressLine(viewModel: viewModel, theme: theme, height: 2)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(viewModel.modeLabel)
                                .font(theme.currentFont.font(size: 9, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(theme.colors.textSecondary)
                            Spacer()
                            Text(viewModel.engine.formattedTime)
                                .font(theme.currentFont.font(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.colors.text)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        TimerProgressLine(viewModel: viewModel, theme: theme, height: 2)
                    }
                    .padding(10)
                }
            }
            .cardBackground(theme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .help("\(viewModel.modeLabel.capitalized) session — back to Focus")
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
