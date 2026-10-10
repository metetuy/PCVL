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

/// Selected section, shared between the controller (which opens the window on a
/// section) and the window's sidebar.
@MainActor
final class WindowNavigation: ObservableObject {
    @Published var section: WindowSection = .focus
}

// MARK: - Main Window Controller

/// Owns the resizable desktop window: a regular titled window that supports native
/// full screen, remembers its frame (including which display it was on), and is
/// created lazily the first time it is opened.
@MainActor
final class MainWindowController {
    private var window: NSWindow?
    private let navigation = WindowNavigation()

    private let timerViewModel: TimerViewModel
    private let themeManager: ThemeManager
    private let statsManager: StatisticsManager
    private let analyticsViewModel: AnalyticsViewModel
    private let onCollapse: () -> Void

    static let defaultSize = NSSize(width: 1080, height: 720)
    static let minimumSize = NSSize(width: 720, height: 500)

    init(
        timerViewModel: TimerViewModel,
        themeManager: ThemeManager,
        statsManager: StatisticsManager,
        analyticsViewModel: AnalyticsViewModel,
        onCollapse: @escaping () -> Void
    ) {
        self.timerViewModel = timerViewModel
        self.themeManager = themeManager
        self.statsManager = statsManager
        self.analyticsViewModel = analyticsViewModel
        self.onCollapse = onCollapse
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show(section: WindowSection) {
        navigation.section = section
        let window = self.window ?? makeWindow()
        self.window = window
        if section == .analytics {
            analyticsViewModel.refresh()
        }
        // The app has no Dock icon, so activate explicitly to bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
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
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.collectionBehavior = [.fullScreenPrimary]
        window.animationBehavior = .documentWindow
        window.contentMinSize = Self.minimumSize

        let root = MainWindowView(
            navigation: navigation,
            timerViewModel: timerViewModel,
            theme: themeManager,
            statsManager: statsManager,
            analytics: analyticsViewModel,
            onCollapse: onCollapse,
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
