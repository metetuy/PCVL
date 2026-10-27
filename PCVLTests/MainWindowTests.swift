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
        themeManager: ThemeManager = ThemeManager(),
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
        let settings = AppSettings(statsManager: stats, updater: Updater(defaults: UserDefaults(suiteName: "PCVLTests.MainWindow")!))
        let timer = TimerViewModel()
        let taskManager = TaskManager(statsManager: stats, defaults: UserDefaults(suiteName: "PCVLTests.MainWindow")!)
        let controller = MainWindowController(
            timerViewModel: timer,
            themeManager: themeManager,
            settings: settings,
            statsSummary: StatsSummaryViewModel(statsManager: stats, settings: settings),
            tasksViewModel: TasksViewModel(taskManager: taskManager, statsManager: stats, timer: timer),
            analyticsViewModel: AnalyticsViewModel(statsManager: stats, settings: settings),
            taskAnalyticsViewModel: TaskAnalyticsViewModel(statsManager: stats, taskManager: taskManager),
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

    /// Bounds (in window coordinates) of the system-red pixels in the left half of
    /// the window's content: the theme editor's Delete control. SwiftUI exposes too
    /// little accessibility here to find the button by name. The right half holds
    /// the picker's red swatch, so it is left out.
    private func redBounds(in window: NSWindow) throws -> NSRect? {
        let view = try #require(window.contentView)
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / view.bounds.width
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<rep.pixelsHigh {
            for x in 0..<(rep.pixelsWide / 2) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if color.redComponent > 0.85, color.greenComponent < 0.45, color.blueComponent < 0.45 {
                    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        // Bitmap rows run top-down; window coordinates bottom-up.
        return NSRect(
            x: CGFloat(minX) / scale,
            y: view.bounds.height - CGFloat(maxY + 1) / scale,
            width: CGFloat(maxX - minX + 1) / scale,
            height: CGFloat(maxY - minY + 1) / scale
        )
    }

    /// A click through the application, so local event monitors see it too.
    private func appClick(_ window: NSWindow, at point: NSPoint) {
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            )!
            NSApp.sendEvent(event)
        }
    }

    /// Deleting a theme takes the trash circle that replaces Delete. It stays armed
    /// whatever the pointer does, and the next click anywhere else (including a
    /// double click's second click on "Are you sure?") puts Delete back.
    @Test func deletingAThemeTakesTheConfirmingCircle() async throws {
        let suite = "PCVLTests.MainWindow.Themes.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let themeManager = ThemeManager(defaults: defaults)
        let custom = CustomTheme(name: "Doomed", palette: ThemePalette(ThemeManager.colors(for: .ocean)))
        themeManager.saveCustomTheme(custom)

        try await withWindow(themeManager: themeManager) { controller, window in
            controller.state.themeEditor = ThemeEditorViewModel(themeManager: themeManager, editing: custom)
            controller.show(section: .settings)
            await settle()

            let idle = try #require(try redBounds(in: window), "Delete is drawn in red")
            let delete = NSPoint(x: idle.midX, y: idle.midY)

            appClick(window, at: delete)
            await settle()
            let armed = try #require(try redBounds(in: window))
            #expect(armed.width > idle.width, "armed, it widens into the red bar")

            // Another click, here on "Are you sure?" where Delete was: disarms, deletes nothing.
            appClick(window, at: delete)
            await settle()
            #expect(themeManager.customThemes == [custom])
            #expect(try redBounds(in: window)?.width == idle.width, "back to Delete")

            appClick(window, at: delete)
            await settle()
            // The trash circle sits at the bar's leading end, one bar-height wide.
            appClick(window, at: NSPoint(x: armed.minX + armed.height / 2, y: armed.midY))
            await settle()
            #expect(themeManager.customThemes.isEmpty)
            #expect(controller.state.themeEditor == nil, "deleting closes the editor")
        }
    }

    /// Center of the sidebar toggle in the top bar (which fills the title bar), from
    /// the window's top-left.
    private func sidebarButtonCenter(_ state: WindowState, in window: NSWindow) -> (x: CGFloat, y: CGFloat) {
        let sidebar = state.isSidebarCollapsed ? MainWindowView.collapsedSidebarWidth : MainWindowView.sidebarWidth
        let titleBar = max(window.contentView?.safeAreaInsets.top ?? 0, MainWindowView.minimumTopBarHeight)
        return (sidebar + 0.5 + 14 + 13, titleBar / 2)
    }

    /// The panel's "Create Theme…" lands on a new draft in the settings, which
    /// survives switching sections.
    @Test func showThemeEditorOpensSettingsOnNewDraft() async throws {
        try await withWindow { controller, window in
            controller.showThemeEditor()
            await settle()
            let state = controller.state
            let editor = try #require(state.themeEditor)
            #expect(state.section == .settings)
            #expect(!editor.isEditing)
            #expect(window.isVisible)

            state.section = .focus
            await settle()
            state.section = .settings
            #expect(state.themeEditor === editor)
        }
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
