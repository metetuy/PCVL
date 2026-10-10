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
    private(set) var window: NSWindow?
    let state = WindowState()

    private let timerViewModel: TimerViewModel
    private let themeManager: ThemeManager
    private let settings: AppSettings
    private let statsSummary: StatsSummaryViewModel
    let analyticsViewModel: AnalyticsViewModel
    /// Called once the window has closed because the user switched to the panel.
    private let onSwitchedToPanel: () -> Void

    /// What to do once the window has left full screen (closing a full-screen
    /// window directly would leave its Space behind).
    private var afterExitingFullScreen: (() -> Void)?
    private var sectionObserver: AnyCancellable?

    static let defaultSize = NSSize(width: 1080, height: 720)
    static let minimumSize = NSSize(width: 720, height: 500)

    init(
        timerViewModel: TimerViewModel,
        themeManager: ThemeManager,
        settings: AppSettings,
        statsSummary: StatsSummaryViewModel,
        analyticsViewModel: AnalyticsViewModel,
        onSwitchedToPanel: @escaping () -> Void
    ) {
        self.timerViewModel = timerViewModel
        self.themeManager = themeManager
        self.settings = settings
        self.statsSummary = statsSummary
        self.analyticsViewModel = analyticsViewModel
        self.onSwitchedToPanel = onSwitchedToPanel
        super.init()
        // @Published emits before the change, so the new section comes from the value.
        sectionObserver = state.$section.sink { [weak self] section in
            self?.updateAnalyticsActivity(section: section)
        }
    }

    /// Analytics only recomputes while its screen is shown in an open window.
    private func updateAnalyticsActivity(section: WindowSection? = nil) {
        analyticsViewModel.isActive = isOpen && (section ?? state.section) == .analytics
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
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        // The app has no Dock icon, so activate explicitly to bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        updateAnalyticsActivity()
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

    // No SwiftUI animation here: AppKit animates the full screen transition, and an
    // animated transaction during its frame changes makes NSHostingView animate the
    // window size too, fighting AppKit until the window grows without bound.
    func windowWillEnterFullScreen(_ notification: Notification) {
        state.setFullScreen(true)
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        state.setFullScreen(false)
    }

    /// Full screen hides the (empty) toolbar together with the menu bar, so the
    /// content fills the screen; otherwise AppKit pins an opaque toolbar strip on
    /// top. Both slide in when the pointer reaches the top edge.
    func window(
        _ window: NSWindow,
        willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []
    ) -> NSApplication.PresentationOptions {
        proposedOptions.union([.fullScreen, .autoHideToolbar, .autoHideMenuBar])
    }

    func windowWillClose(_ notification: Notification) {
        analyticsViewModel.isActive = false
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
            settings: settings,
            summary: statsSummary,
            analytics: analyticsViewModel,
            onToggleFullScreen: { [weak self] in self?.toggleFullScreen() },
            onSwitchToPanel: { [weak self] in self?.switchToPanel() },
            onClose: { [weak self] in self?.close() }
        )
        let hostingView = NSHostingView(rootView: root)
        // The window alone owns its size (`contentMinSize` above). Letting SwiftUI
        // publish its own size constraints feeds back into AppKit's layout while the
        // full screen transition resizes the window and the sidebar animates, which
        // grows the window without bound until AppKit throws.
        hostingView.sizingOptions = []
        window.contentView = hostingView

        window.center()
        // Restores the last size and position (and display) after the first launch.
        window.setFrameAutosaveName("PCVLMainWindow")
        return window
    }
}
