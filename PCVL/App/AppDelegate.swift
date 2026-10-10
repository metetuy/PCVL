import SwiftUI
import CoreText
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelWindow: NSPanel!
    private let viewModel = TimerViewModel()
    private let themeManager = ThemeManager()
    private let statsManager = StatisticsManager()
    private lazy var statsSummary = StatsSummaryViewModel(statsManager: statsManager)
    private lazy var analyticsViewModel = AnalyticsViewModel(statsManager: statsManager)
    private lazy var windowController = MainWindowController(
        timerViewModel: viewModel,
        themeManager: themeManager,
        statsManager: statsManager,
        analyticsViewModel: analyticsViewModel,
        onSwitchedToPanel: { [weak self] in self?.showPanelAfterWindowMode() }
    )
    private var defaultsObservers = Set<AnyCancellable>()

    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private var themePickerWindow: NSPanel?
    private var themePickerGlobalMonitor: Any?
    private var themePickerLocalMonitor: Any?

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
            statsManager: statsManager,
            statsSummary: statsSummary,
            onExpand: { [weak self] tab in self?.enterWindowMode(section: WindowSection(tab)) },
            onShowThemePicker: { [weak self] anchorRect in self?.showThemePicker(anchorRect: anchorRect) }
        )

        panelWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 190),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        panelWindow.isFloatingPanel = alwaysOnTop
        panelWindow.level = alwaysOnTop ? .statusBar : .floating
        panelWindow.isOpaque = false
        panelWindow.backgroundColor = .clear
        panelWindow.hasShadow = true
        panelWindow.isMovableByWindowBackground = true
        panelWindow.isReleasedWhenClosed = false
        panelWindow.animationBehavior = .utilityWindow
        panelWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panelWindow.contentView = NSHostingView(rootView: contentView)

        positionWindowNearStatusItem()
        observeDefaults()
    }

    /// The panel, the window's settings and the context menu all just write these
    /// defaults; reacting here keeps every entry point in sync.
    private func observeDefaults() {
        UserDefaults.standard.publisher(for: \.alwaysOnTop)
            .dropFirst()
            .removeDuplicates()
            // Deferred: these change from SwiftUI updates, and mutating the panel
            // mid-update re-enters AppKit's layout pass.
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.applyAlwaysOnTop(enabled) }
            .store(in: &defaultsObservers)

        UserDefaults.standard.publisher(for: \.showTimerInMenuBar)
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.viewModel.updateMenuBarIcon()
                self?.updateEventMonitors()
            }
            .store(in: &defaultsObservers)
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

    private var shouldPreventAutoClose: Bool {
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        let timerInMenuBar = UserDefaults.standard.bool(forKey: "showTimerInMenuBar")
        return alwaysOnTop && !timerInMenuBar
    }

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
                   event.window != self.themePickerWindow {
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
            hideThemePicker()
            viewModel.updateMenuBarIcon()
        }
    }

    // MARK: - Theme Picker Flyout

    /// Shows the theme list in its own borderless panel that pops out beside the
    /// main panel (like a submenu), rather than rendering inline in the popup.
    private func showThemePicker(anchorRect: CGRect) {
        // Deferred: creating and ordering a new panel synchronously from a
        // SwiftUI button action re-enters AppKit's layout pass mid-tap.
        DispatchQueue.main.async { [weak self] in
            self?.presentThemePicker(anchorRect: anchorRect)
        }
    }

    private func presentThemePicker(anchorRect: CGRect) {
        hideThemePicker()

        let width = ThemeFlyoutView.width
        let height = ThemeFlyoutView.height

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow

        let content = ThemeFlyoutView(theme: themeManager) { [weak self] selected in
            self?.themeManager.currentTheme = selected
        }
        panel.contentView = NSHostingView(rootView: content)

        let mainFrame = panelWindow.frame
        let buttonTopScreenY = mainFrame.origin.y + mainFrame.height - anchorRect.minY
        var originX = mainFrame.origin.x + mainFrame.width + 6
        var originY = buttonTopScreenY - height

        if let screenFrame = panelWindow.screen?.visibleFrame {
            if originX + width > screenFrame.maxX {
                originX = mainFrame.origin.x - width - 6
            }
            originY = min(originY, screenFrame.maxY - height)
            originY = max(originY, screenFrame.minY)
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        panel.orderFront(nil)
        themePickerWindow = panel

        themePickerGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideThemePicker()
        }
        themePickerLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, event.window != self.themePickerWindow {
                self.hideThemePicker()
            }
            return event
        }
    }

    private func hideThemePicker() {
        if let monitor = themePickerGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            themePickerGlobalMonitor = nil
        }
        if let monitor = themePickerLocalMonitor {
            NSEvent.removeMonitor(monitor)
            themePickerLocalMonitor = nil
        }
        themePickerWindow?.orderOut(nil)
        themePickerWindow = nil
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        if windowController.isOpen {
            let showItem = NSMenuItem(title: "Show PCVL Window", action: #selector(openWindowFromMenu), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)

            let panelItem = NSMenuItem(title: "Switch to Menu Bar Panel", action: #selector(switchToPanelFromMenu), keyEquivalent: "")
            panelItem.target = self
            menu.addItem(panelItem)
        } else {
            let openItem = NSMenuItem(title: "Open PCVL Window", action: #selector(openWindowFromMenu), keyEquivalent: "")
            openItem.target = self
            menu.addItem(openItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Timer durations
        let workItem = NSMenuItem(title: "Work: \(viewModel.workDuration / 60) min", action: nil, keyEquivalent: "")
        let workMenu = NSMenu()
        for mins in stride(from: 30, through: 120, by: 15) {
            let item = NSMenuItem(title: "\(mins) min", action: #selector(setWorkDuration(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mins
            if mins == viewModel.workDuration / 60 {
                item.state = .on
            }
            workMenu.addItem(item)
        }
        workItem.submenu = workMenu
        menu.addItem(workItem)

        let breakItem = NSMenuItem(title: "Break: \(viewModel.breakDuration / 60) min", action: nil, keyEquivalent: "")
        let breakMenu = NSMenu()
        for mins in stride(from: 5, through: 30, by: 5) {
            let item = NSMenuItem(title: "\(mins) min", action: #selector(setBreakDuration(_:)), keyEquivalent: "")
            item.target = self
            item.tag = mins
            if mins == viewModel.breakDuration / 60 {
                item.state = .on
            }
            breakMenu.addItem(item)
        }
        breakItem.submenu = breakMenu
        menu.addItem(breakItem)

        menu.addItem(NSMenuItem.separator())

        // Theme picker
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for appTheme in AppTheme.allCases {
            let item = NSMenuItem(title: appTheme.rawValue, action: #selector(setTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = appTheme
            if appTheme == themeManager.currentTheme {
                item.state = .on
            }
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(NSMenuItem.separator())

        // Font picker
        let fontItem = NSMenuItem(title: "Font", action: nil, keyEquivalent: "")
        let fontMenu = NSMenu()
        for appFont in AppFont.allCases {
            let item = NSMenuItem(title: appFont.rawValue, action: #selector(setFont(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = appFont
            if appFont == themeManager.currentFont {
                item.state = .on
            }
            fontMenu.addItem(item)
        }
        fontItem.submenu = fontMenu
        menu.addItem(fontItem)

        menu.addItem(NSMenuItem.separator())

        // Toggles
        let alwaysOnTopItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        alwaysOnTopItem.state = UserDefaults.standard.bool(forKey: "alwaysOnTop") ? .on : .off
        menu.addItem(alwaysOnTopItem)

        let menuBarTimerItem = NSMenuItem(title: "Timer in Menu Bar", action: #selector(toggleMenuBarTimer), keyEquivalent: "")
        menuBarTimerItem.target = self
        menuBarTimerItem.state = UserDefaults.standard.bool(forKey: "showTimerInMenuBar") ? .on : .off
        menu.addItem(menuBarTimerItem)

        menu.addItem(NSMenuItem.separator())

        // Reset statistics
        let resetItem = NSMenuItem(title: "Reset Statistics…", action: #selector(resetStatistics), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit PCVL", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Clear the menu so left-click goes back to togglePanel
        statusItem.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func setWorkDuration(_ sender: NSMenuItem) {
        guard viewModel.isIdle else { return }
        viewModel.workDuration = sender.tag * 60
    }

    @objc private func setBreakDuration(_ sender: NSMenuItem) {
        guard viewModel.isIdle else { return }
        viewModel.breakDuration = sender.tag * 60
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? AppTheme else { return }
        themeManager.currentTheme = theme
    }

    @objc private func setFont(_ sender: NSMenuItem) {
        guard let font = sender.representedObject as? AppFont else { return }
        themeManager.currentFont = font
    }

    @objc private func openWindowFromMenu() {
        if windowController.isOpen {
            windowController.bringToFront()
        } else {
            enterWindowMode(section: .focus)
        }
    }

    @objc private func switchToPanelFromMenu() {
        windowController.switchToPanel()
    }

    @objc private func toggleAlwaysOnTop() {
        UserDefaults.standard.alwaysOnTop.toggle()
    }

    @objc private func toggleMenuBarTimer() {
        UserDefaults.standard.showTimerInMenuBar.toggle()
    }

    @objc private func resetStatistics() {
        let alert = NSAlert()
        alert.messageText = "Reset Statistics"
        alert.informativeText = "Are you sure you want to delete all session records? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            statsManager.deleteAllSessions()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
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
        if UserDefaults.standard.showTimerInMenuBar && isRunning {
            button.title = "\(time) "
            button.imagePosition = .imageRight
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
}

// MARK: - Observable Defaults

/// KVO-visible accessors (names match the keys) so changes can be observed.
extension UserDefaults {
    @objc dynamic var alwaysOnTop: Bool {
        get { bool(forKey: "alwaysOnTop") }
        set { set(newValue, forKey: "alwaysOnTop") }
    }

    @objc dynamic var showTimerInMenuBar: Bool {
        get { bool(forKey: "showTimerInMenuBar") }
        set { set(newValue, forKey: "showTimerInMenuBar") }
    }
}
