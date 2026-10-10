import AppKit
import SwiftUI
import Combine

// MARK: - Window Section

enum WindowSection: String, CaseIterable, Identifiable {
    case focus
    case analytics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .analytics: return "chart.bar"
        case .settings: return "gear"
        }
    }

    /// The window section that corresponds to a panel tab.
    init(_ tab: AppTab) {
        switch tab {
        case .timer: self = .focus
        case .stats: self = .analytics
        case .settings: self = .settings
        }
    }
}

/// UI state of the window shared between the controller and the SwiftUI views:
/// selected section, full screen, and whether the sidebar shows icons only.
@MainActor
final class WindowState: ObservableObject {
    @Published var section: WindowSection = .focus
    @Published private(set) var isFullScreen = false
    @Published private(set) var isSidebarCollapsed: Bool

    private static let sidebarKey = "windowSidebarCollapsed"
    /// The windowed sidebar state to restore when leaving full screen.
    private var collapsedBeforeFullScreen = false

    init() {
        isSidebarCollapsed = UserDefaults.standard.bool(forKey: Self.sidebarKey)
    }

    func toggleSidebar() {
        isSidebarCollapsed.toggle()
        // Only the windowed preference is remembered; full screen always starts collapsed.
        if !isFullScreen {
            UserDefaults.standard.set(isSidebarCollapsed, forKey: Self.sidebarKey)
        }
    }

    fileprivate func setFullScreen(_ fullScreen: Bool) {
        guard fullScreen != isFullScreen else { return }
        isFullScreen = fullScreen
        if fullScreen {
            collapsedBeforeFullScreen = isSidebarCollapsed
            isSidebarCollapsed = true
        } else {
            isSidebarCollapsed = collapsedBeforeFullScreen
        }
    }
}

// MARK: - Main Window Controller

/// Owns the resizable desktop window: a regular titled window whose native full
/// screen is an extension of the same window. It remembers its frame (including
/// which display it was on) and is created lazily the first time it is opened.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let state = WindowState()

    private let timerViewModel: TimerViewModel
    private let themeManager: ThemeManager
    private let statsManager: StatisticsManager
    private let analyticsViewModel: AnalyticsViewModel
    /// Called once the window has closed because the user switched to the panel.
    private let onSwitchedToPanel: () -> Void

    /// What to do once the window has left full screen (closing a full-screen
    /// window directly would leave its Space behind).
    private var afterExitingFullScreen: (() -> Void)?

    static let defaultSize = NSSize(width: 1080, height: 720)
    static let minimumSize = NSSize(width: 720, height: 500)

    init(
        timerViewModel: TimerViewModel,
        themeManager: ThemeManager,
        statsManager: StatisticsManager,
        analyticsViewModel: AnalyticsViewModel,
        onSwitchedToPanel: @escaping () -> Void
    ) {
        self.timerViewModel = timerViewModel
        self.themeManager = themeManager
        self.statsManager = statsManager
        self.analyticsViewModel = analyticsViewModel
        self.onSwitchedToPanel = onSwitchedToPanel
    }

    /// Window mode is active while the window is on screen or minimized to the Dock.
    var isOpen: Bool {
        guard let window else { return false }
        return window.isVisible || window.isMiniaturized
    }

    func show(section: WindowSection) {
        state.section = section
        bringToFront()
    }

    /// Brings the window back without changing the section (e.g. from the menu bar icon).
    func bringToFront() {
        let window = self.window ?? makeWindow()
        self.window = window
        if state.section == .analytics {
            analyticsViewModel.refresh()
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        // The app has no Dock icon, so activate explicitly to bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func toggleFullScreen() {
        // Deferred: invoked from a SwiftUI button action.
        DispatchQueue.main.async { [weak self] in
            self?.window?.toggleFullScreen(nil)
        }
    }

    /// Ends window mode and hands over to the menu bar panel.
    func switchToPanel() {
        dismiss { [weak self] in self?.onSwitchedToPanel() }
    }

    /// Closes the window, leaving full screen first if needed.
    func close() {
        dismiss(then: nil)
    }

    private func dismiss(then completion: (() -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.styleMask.contains(.fullScreen) {
                self.afterExitingFullScreen = { [weak self] in
                    self?.window?.close()
                    completion?()
                }
                window.toggleFullScreen(nil)
            } else {
                window.close()
                completion?()
            }
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillEnterFullScreen(_ notification: Notification) {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.setFullScreen(true)
        }
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        withAnimation(.easeInOut(duration: 0.25)) {
            state.setFullScreen(false)
        }
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        let pending = afterExitingFullScreen
        afterExitingFullScreen = nil
        pending?()
    }

    func windowDidFailToExitFullScreen(_ window: NSWindow) {
        afterExitingFullScreen = nil
    }

    // MARK: - Setup

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PCVL"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // An empty compact toolbar gives a taller title bar, so the traffic lights line
        // up with the window's own top bar controls.
        window.toolbar = NSToolbar(identifier: "PCVLMainWindowToolbar")
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.fullScreenPrimary]
        window.animationBehavior = .documentWindow
        window.contentMinSize = Self.minimumSize
        window.delegate = self

        let root = MainWindowView(
            state: state,
            timerViewModel: timerViewModel,
            theme: themeManager,
            statsManager: statsManager,
            analytics: analyticsViewModel,
            onToggleFullScreen: { [weak self] in self?.toggleFullScreen() },
            onSwitchToPanel: { [weak self] in self?.switchToPanel() },
            onClose: { [weak self] in self?.close() }
        )
        let hostingView = NSHostingView(rootView: root)
        // Let the user drive the size; SwiftUI only enforces the minimum.
        hostingView.sizingOptions = [.minSize]
        window.contentView = hostingView

        window.center()
        // Restores the last size and position (and display) after the first launch.
        window.setFrameAutosaveName("PCVLMainWindow")
        return window
    }
}
