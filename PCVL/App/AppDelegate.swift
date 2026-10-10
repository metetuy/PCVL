import SwiftUI
import CoreText
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelWindow: NSPanel!
    private let viewModel = TimerViewModel()
    private let themeManager = ThemeManager()
    private let statsManager = StatisticsManager()
    private lazy var settings = AppSettings(statsManager: statsManager)
    private lazy var statsSummary = StatsSummaryViewModel(statsManager: statsManager, settings: settings)
    private lazy var analyticsViewModel = AnalyticsViewModel(statsManager: statsManager, settings: settings)
    private lazy var windowController = MainWindowController(
        timerViewModel: viewModel,
        themeManager: themeManager,
        settings: settings,
        statsSummary: statsSummary,
        analyticsViewModel: analyticsViewModel,
        onSwitchedToPanel: { [weak self] in self?.showPanelAfterWindowMode() }
    )
    private lazy var themeFlyout = ThemeFlyoutController(themeManager: themeManager)
    private lazy var statusMenu = StatusItemMenu(
        timer: viewModel,
        themeManager: themeManager,
        settings: settings,
        isWindowOpen: { [weak self] in self?.windowController.isOpen ?? false },
        onOpenWindow: { [weak self] in self?.openWindow() },
        onSwitchToPanel: { [weak self] in self?.windowController.switchToPanel() }
    )
    private var settingsObservers = Set<AnyCancellable>()

    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register custom fonts
        registerFonts()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.action = #selector(handleStatusItemClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        viewModel.setStatisticsManager(statsManager)
        viewModel.menuBarUpdater = { [weak self] time, isRunning in
            self?.updateMenuBar(time: time, isRunning: isRunning)
        }

        let contentView = PopoverView(
            viewModel: viewModel,
            themeManager: themeManager,
            settings: settings,
            statsSummary: statsSummary,
            onExpand: { [weak self] tab in self?.enterWindowMode(section: WindowSection(tab)) },
            onShowThemePicker: { [weak self] anchorRect in
                guard let self else { return }
                self.themeFlyout.show(beside: self.panelWindow, anchorRect: anchorRect)
            }
        )

        panelWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 190),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panelWindow.isFloatingPanel = settings.alwaysOnTop
        panelWindow.level = settings.alwaysOnTop ? .statusBar : .floating
        panelWindow.isOpaque = false
        panelWindow.backgroundColor = .clear
        panelWindow.hasShadow = true
        panelWindow.isMovableByWindowBackground = true
        panelWindow.isReleasedWhenClosed = false
        panelWindow.animationBehavior = .utilityWindow
        panelWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panelWindow.contentView = NSHostingView(rootView: contentView)

        positionWindowNearStatusItem()
        observeSettings()
    }

    /// The panel, the window's settings and the context menu all write `AppSettings`;
    /// reacting here keeps every entry point in sync.
    private func observeSettings() {
        settings.$alwaysOnTop
            .dropFirst()
            .removeDuplicates()
            // Deferred: these change from SwiftUI updates, and mutating the panel
            // mid-update re-enters AppKit's layout pass. Also lets the published value
            // land before it is read back.
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.applyAlwaysOnTop(enabled) }
            .store(in: &settingsObservers)

        settings.$showTimerInMenuBar
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.viewModel.updateMenuBarIcon() }
            .store(in: &settingsObservers)
    }

    // MARK: - Status Item Click Handling

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else if windowController.isOpen {
            // In window mode the panel is disabled; the icon brings the window back.
            windowController.bringToFront()
        } else {
            togglePanel()
        }
    }

    /// Relaunching the running app (Finder, Spotlight) shows whichever mode is active.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if windowController.isOpen {
            windowController.bringToFront()
        } else if !panelWindow.isVisible {
            showPanel()
        }
        return false
    }

    private func togglePanel() {
        if panelWindow.isVisible {
            closePanel()
        } else {
            showPanel()
        }
        viewModel.updateMenuBarIcon()
    }

    private func showPanel() {
        positionWindowNearStatusItem()
        // Bring the app to foreground first so the panel is presented above active app windows.
        NSApp.activate(ignoringOtherApps: true)
        panelWindow.orderFront(nil)
        updateEventMonitors()
    }

    // MARK: - Window

    /// Panel → window. Every way into the window goes through here so the panel is
    /// always put away first (it stays disabled while the window is open).
    private func enterWindowMode(section: WindowSection) {
        // Deferred: may be invoked from a SwiftUI button action in the panel.
        DispatchQueue.main.async { [weak self] in
            self?.closePanel()
            self?.windowController.show(section: section)
        }
    }

    /// Window → panel, once the window (and its full screen Space, if any) has closed.
    private func showPanelAfterWindowMode() {
        showPanel()
        viewModel.updateMenuBarIcon()
    }

    /// Always on Top keeps the panel open when clicking elsewhere.
    private var shouldPreventAutoClose: Bool { settings.alwaysOnTop }

    private func updateEventMonitors() {
        guard panelWindow.isVisible else {
            stopEventMonitors()
            return
        }
        
        if shouldPreventAutoClose {
            stopEventMonitors()
        } else {
            startEventMonitors()
        }
    }

    private func startEventMonitors() {
        if globalEventMonitor == nil {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.handleOutsideClick()
            }
        }
        if localEventMonitor == nil {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let self = self,
                   event.window != self.panelWindow,
                   event.window != self.statusItem.button?.window,
                   event.window != self.themeFlyout.window {
                    self.handleOutsideClick()
                }
                return event
            }
        }
    }

    private func stopEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    private func handleOutsideClick() {
        guard panelWindow.attachedSheet == nil else { return }
        if !shouldPreventAutoClose {
            closePanel()
        }
    }

    private func closePanel() {
        if panelWindow.isVisible {
            panelWindow.orderOut(nil)
            stopEventMonitors()
            themeFlyout.hide()
            viewModel.updateMenuBarIcon()
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        statusItem.menu = statusMenu.makeMenu()
        statusItem.button?.performClick(nil)
        // Clear the menu so left-click goes back to togglePanel
        statusItem.menu = nil
    }

    private func openWindow() {
        if windowController.isOpen {
            windowController.bringToFront()
        } else {
            enterWindowMode(section: .focus)
        }
    }

    // MARK: - Font Registration
    
    private func registerFonts() {
        let fontFileNames = ["Inter-VariableFont_opsz,wght.ttf"]
        
        for fontFileName in fontFileNames {
            guard let fontURL = Bundle.main.url(forResource: fontFileName, withExtension: nil) else {
                NSLog("Font file not found: \(fontFileName)")
                continue
            }
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                NSLog("Failed to register font: \(fontFileName)")
            }
        }
    }

    private func positionWindowNearStatusItem() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let windowSize = panelWindow.frame.size
        let x = screenRect.midX - windowSize.width / 2
        let y = screenRect.minY - windowSize.height - 4

        panelWindow.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func applyAlwaysOnTop(_ enabled: Bool) {
        panelWindow.isFloatingPanel = enabled
        panelWindow.level = enabled ? .statusBar : .floating
        updateEventMonitors()
    }

    /// Called every tick while running, so it only touches the title.
    func updateMenuBar(time: String, isRunning: Bool) {
        guard let button = statusItem.button else { return }
        if settings.showTimerInMenuBar && isRunning {
            button.title = "\(time) "
            button.imagePosition = .imageRight
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
}
