import SwiftUI

// MARK: - Tab Enum

enum AppTab: CaseIterable {
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
    @State private var swipeDelta: CGFloat = 0

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
        .frame(width: 280, height: 180)
        .background(themeManager.colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        // Only handle direct touch-phase events, not momentum
        guard event.momentumPhase == .init(rawValue: 0) else { return }

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
