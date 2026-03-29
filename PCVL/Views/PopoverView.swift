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
            .overlay(SwipeGestureView { direction in
                withAnimation(.easeInOut(duration: 0.15)) {
                    switchTab(direction)
                }
            })
        }
        .frame(width: 280, height: 180)
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
                .font(.system(size: 12))
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

struct SwipeGestureView: NSViewRepresentable {
    var onSwipe: (SwipeDirection) -> Void

    func makeNSView(context: Context) -> SwipeNSView {
        let view = SwipeNSView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_ nsView: SwipeNSView, context: Context) {
        nsView.onSwipe = onSwipe
    }
}

class SwipeNSView: NSView {
    var onSwipe: ((SwipeDirection) -> Void)?
    private var accumulatedDeltaX: CGFloat = 0
    private let threshold: CGFloat = 30

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard event.momentumPhase == .init(rawValue: 0) else { return }

        if event.phase == .began {
            accumulatedDeltaX = 0
        }

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
