import SwiftUI

// MARK: - Main Window View

/// Shell of the desktop window: a sidebar with the three sections and the
/// selected screen. Each screen lives in its own file.
struct MainWindowView: View {
    @ObservedObject var navigation: WindowNavigation
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    let statsManager: StatisticsManager
    let analytics: AnalyticsViewModel
    let onCollapse: () -> Void
    let onClose: () -> Void

    static let sidebarWidth: CGFloat = 196

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Self.sidebarWidth)

            Rectangle()
                .fill(theme.colors.ringTrack)
                .frame(width: 0.5)
                .ignoresSafeArea()

            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: MainWindowController.minimumSize.width, minHeight: MainWindowController.minimumSize.height)
        .background(ThemedBackground(theme: theme, radius: 900).ignoresSafeArea())
        .background(closeShortcut)
    }

    @ViewBuilder
    private var screen: some View {
        switch navigation.section {
        case .focus:
            FocusScreen(viewModel: timerViewModel, theme: theme)
        case .analytics:
            AnalyticsScreen(viewModel: analytics, theme: theme)
        case .settings:
            SettingsScreen(timerViewModel: timerViewModel, theme: theme, statsManager: statsManager)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PCVL")
                .font(theme.currentFont.font(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(theme.colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            ForEach(Array(WindowSection.allCases.enumerated()), id: \.element) { index, section in
                SidebarItem(
                    section: section,
                    shortcut: Character("\(index + 1)"),
                    isSelected: navigation.section == section,
                    theme: theme
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        navigation.section = section
                    }
                }
            }

            Spacer()

            if !timerViewModel.isIdle && navigation.section != .focus {
                sessionStatus
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }

            collapseButton
        }
        .padding(.horizontal, 12)
        // Clears the window's traffic-light buttons.
        .padding(.top, 44)
        .padding(.bottom, 14)
        .animation(.easeInOut(duration: 0.15), value: timerViewModel.isIdle)
    }

    /// Live timer readout while another section is shown; clicking returns to Focus.
    private var sessionStatus: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                navigation.section = .focus
            }
        } label: {
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
            .cardBackground(theme)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    /// Mirror of the panel's "Expand for details" handle.
    private var collapseButton: some View {
        Button(action: onCollapse) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(theme.currentFont.font(size: 9, weight: .bold))
                Text("Collapse to menu bar")
                    .font(theme.currentFont.font(size: 11, weight: .medium))
            }
            .foregroundColor(theme.colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .help("Close the window and open the menu bar panel")
    }

    /// The app has no main menu, so ⌘W is provided here.
    private var closeShortcut: some View {
        Button("Close", action: onClose)
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: WindowSection
    let shortcut: Character
    let isSelected: Bool
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(theme.currentFont.font(size: 13))
                    .frame(width: 18)
                Text(section.title)
                    .font(theme.currentFont.font(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer()
                Text("⌘\(String(shortcut))")
                    .font(theme.currentFont.font(size: 10))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.7))
            }
            .foregroundColor(isSelected ? theme.colors.accent : theme.colors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .keyboardShortcut(KeyEquivalent(shortcut), modifiers: .command)
    }
}
