import AppKit
import Testing
@testable import PCVL

/// Drives the real desktop window with synthesized clicks, so hit testing and
/// AppKit layout run exactly as they do for the user.
@MainActor
@Suite(.serialized)
struct MainWindowTests {
    private static let preservedKeys = ["NSWindow Frame PCVLMainWindow", "windowSidebarCollapsed"]

    /// Runs `body` with a fresh window controller, restoring the user's saved
    /// window frame and sidebar preference afterwards.
    private func withWindow(
        sessions: Int = 0,
        _ body: (MainWindowController, NSWindow) async throws -> Void
    ) async throws {
        let defaults = UserDefaults.standard
        let saved = Self.preservedKeys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved { defaults.set(value, forKey: key) }
        }

        let stats = StatisticsManager(inMemory: true)
        for index in 0..<sessions {
            let type: SessionType = index % 3 == 0 ? .shortBreak : (index % 5 == 0 ? .stopwatch : .work)
            stats.recordSession(duration: 600 + index * 37 % 4000, date: Date().addingTimeInterval(-Double(index) * 5400), type: type)
        }
        let settings = AppSettings(statsManager: stats)
        let timer = TimerViewModel()
        let controller = MainWindowController(
            timerViewModel: timer,
            themeManager: ThemeManager(),
            settings: settings,
            statsSummary: StatsSummaryViewModel(statsManager: stats, settings: settings),
            tasksViewModel: TasksViewModel(
                taskManager: TaskManager(statsManager: stats, defaults: UserDefaults(suiteName: "PCVLTests.MainWindow")!),
                statsManager: stats,
                timer: timer
            ),
            analyticsViewModel: AnalyticsViewModel(statsManager: stats, settings: settings),
            onSwitchedToPanel: {}
        )
        controller.show(section: .focus)
        let window = try #require(controller.window)
        window.setFrame(NSRect(x: 100, y: 100, width: 1080, height: 720), display: true)
        await settle()
        try await body(controller, window)
        window.close()
    }

    /// Lets AppKit and SwiftUI finish pending layout and animations.
    private func settle(_ seconds: Double = 0.4) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Clicks at a point given from the window's top-left corner.
    private func click(_ window: NSWindow, x: CGFloat, fromTop y: CGFloat) {
        let point = NSPoint(x: x, y: window.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            )!
            window.sendEvent(event)
        }
    }

    /// Center of the sidebar toggle in the top bar (which fills the title bar), from
    /// the window's top-left.
    private func sidebarButtonCenter(_ state: WindowState, in window: NSWindow) -> (x: CGFloat, y: CGFloat) {
        let sidebar = state.isSidebarCollapsed ? MainWindowView.collapsedSidebarWidth : MainWindowView.sidebarWidth
        let titleBar = max(window.contentView?.safeAreaInsets.top ?? 0, MainWindowView.minimumTopBarHeight)
        return (sidebar + 0.5 + 14 + 13, titleBar / 2)
    }

    @Test(arguments: WindowSection.allCases)
    func sidebarButtonTogglesOnClick(section: WindowSection) async throws {
        try await withWindow(sessions: 50) { controller, window in
            controller.show(section: section)
            await settle()
            let state = controller.state
            for _ in 0..<4 {
                let before = state.isSidebarCollapsed
                let target = sidebarButtonCenter(state, in: window)
                click(window, x: target.x, fromTop: target.y)
                await settle()
                #expect(state.isSidebarCollapsed != before, "\(section): click on the sidebar button did not toggle it")
            }
        }
    }

    @Test(arguments: WindowSection.allCases)
    func sidebarToggleKeepsWindowSize(section: WindowSection) async throws {
        try await withWindow { controller, window in
            controller.show(section: section)
            await settle()
            let size = window.frame.size
            for _ in 0..<4 {
                controller.state.toggleSidebar()
                await settle()
                #expect(window.frame.size == size, "window resized itself to \(window.frame.size)")
            }
        }
    }

    @Test func windowCanShrinkToItsMinimum() async throws {
        try await withWindow { controller, window in
            for section in WindowSection.allCases {
                controller.show(section: section)
                window.setContentSize(MainWindowController.minimumSize)
                await settle()
                #expect(window.frame.width <= MainWindowController.minimumSize.width + 1, "\(section) forces a wider window")
            }
        }
    }

    @Test func sidebarToggleInFullScreen() async throws {
        try await withWindow(sessions: 300) { controller, window in
            for section in WindowSection.allCases {
                controller.show(section: section)
                controller.toggleFullScreen()
                await settle(2)
                #expect(window.styleMask.contains(.fullScreen))
                #expect(controller.state.isSidebarCollapsed)
                // The toolbar auto-hides, so no opaque strip is pinned above the content.
                #expect(window.contentView?.safeAreaInsets.top == 0, "\(section): toolbar strip is pinned in full screen")

                for _ in 0..<3 {
                    let before = controller.state.isSidebarCollapsed
                    let target = sidebarButtonCenter(controller.state, in: window)
                    click(window, x: target.x, fromTop: target.y)
                    await settle()
                    #expect(controller.state.isSidebarCollapsed != before, "\(section): full screen click did not toggle")
                }
                // The height can be shorter than the screen (camera housing), never the width.
                let screen = try #require(window.screen).frame
                #expect(window.frame.width == screen.width, "\(section): full screen window is \(window.frame.size)")

                controller.toggleFullScreen()
                await settle(2)
                #expect(!window.styleMask.contains(.fullScreen))
                #expect(window.frame.width < 2000, "\(section): window grew to \(window.frame.size)")
            }
        }
    }

    @Test func analyticsWithDataKeepsWindowSize() async throws {
        try await withWindow(sessions: 300) { controller, window in
            controller.show(section: .analytics)
            await settle()
            let size = window.frame.size
            for range in StatsRange.allCases {
                controller.analyticsViewModel.range = range
                controller.state.toggleSidebar()
                await settle()
                #expect(window.frame.size == size, "\(range): window resized itself to \(window.frame.size)")
            }
        }
    }
}
