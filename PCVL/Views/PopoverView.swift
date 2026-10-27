import SwiftUI

// MARK: - Tab Enum

enum AppTab: CaseIterable {
    case timer
    case tasks
    case stats
    case settings
}

// MARK: - Popover View (Shell)

struct PopoverView: View {
    /// Not observed: the engine publishes every second; each tab observes what it shows.
    let viewModel: TimerViewModel
    @ObservedObject var themeManager: ThemeManager
    let settings: AppSettings
    let statsSummary: StatsSummaryViewModel
    let tasks: TasksViewModel
    /// Opens the full window on the section matching the given tab.
    var onExpand: (AppTab) -> Void
    var onShowThemePicker: (CGRect) -> Void

    @State private var selectedTab: AppTab = .timer
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            tabBar
            Divider().background(themeManager.colors.ringTrack)

            // Content
            ZStack {
                switch selectedTab {
                case .timer:
                    TimerView(viewModel: viewModel, theme: themeManager, tasks: tasks) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = .tasks
                        }
                    }
                case .tasks:
                    TasksView(viewModel: tasks, timerViewModel: viewModel, theme: themeManager)
                case .stats:
                    StatsView(viewModel: statsSummary, theme: themeManager)
                case .settings:
                    SettingsView(
                        viewModel: viewModel,
                        theme: themeManager,
                        settings: settings,
                        updater: settings.updater,
                        onShowThemePicker: onShowThemePicker
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            ExpandHandle(theme: themeManager, isPanelHovered: isHovering) {
                onExpand(selectedTab)
            }
            .padding(.bottom, 4)
        }
        .coordinateSpace(name: "panel")
        .frame(width: 300, height: 190)
        .background(ThemedBackground(theme: themeManager))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.colors.text.opacity(0.08), lineWidth: 0.5))
        .onHover { isHovering = $0 }
        .onAppear {
            SwipeMonitor.shared.onSwipe = { direction in
                withAnimation(.easeInOut(duration: 0.15)) {
                    switchTab(direction)
                }
            }
            SwipeMonitor.shared.start()
        }
        .onDisappear {
            SwipeMonitor.shared.stop()
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(tab: .timer, icon: "timer")
            tabButton(tab: .tasks, icon: "checklist")
            tabButton(tab: .stats, icon: "chart.bar")
            tabButton(tab: .settings, icon: "gear")
        }
        .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
        .padding(.horizontal, 8)
    }

    private func tabButton(tab: AppTab, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: icon)
                .font(themeManager.currentFont.font(size: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .foregroundColor(
                    selectedTab == tab
                        ? themeManager.colors.accent
                        : themeManager.colors.textSecondary
                )
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private func switchTab(_ direction: SwipeDirection) {
        let tabs = AppTab.allCases
        guard let idx = tabs.firstIndex(of: selectedTab) else { return }
        switch direction {
        case .left:
            if idx < tabs.count - 1 { selectedTab = tabs[idx + 1] }
        case .right:
            if idx > 0 { selectedTab = tabs[idx - 1] }
        }
    }
}

// MARK: - Swipe Gesture

enum SwipeDirection {
    case left, right
}

/// Uses a local event monitor to detect horizontal swipes without blocking vertical scrolling.
class SwipeMonitor {
    static let shared = SwipeMonitor()

    var onSwipe: ((SwipeDirection) -> Void)?

    private var monitor: Any?
    private var accumulatedDeltaX: CGFloat = 0
    private var isHorizontalGesture: Bool = false
    private let threshold: CGFloat = 30

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            // Always return the event so vertical scrolls reach the ScrollView
            return event
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleScroll(_ event: NSEvent) {
        // Only the panel swipes between tabs; the window scrolls normally.
        guard event.window is NSPanel else { return }
        // Only handle direct touch-phase events, not momentum
        guard event.momentumPhase.isEmpty else { return }

        if event.phase == .began {
            accumulatedDeltaX = 0
            isHorizontalGesture = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }

        guard isHorizontalGesture else { return }

        accumulatedDeltaX += event.scrollingDeltaX

        if event.phase == .ended || event.phase == .cancelled {
            if accumulatedDeltaX > threshold {
                onSwipe?(.right)
            } else if accumulatedDeltaX < -threshold {
                onSwipe?(.left)
            }
            accumulatedDeltaX = 0
        }
    }
}
