import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelWindow: NSPanel!
    private let viewModel = TimerViewModel()
    private let themeManager = ThemeManager()
    private let statsManager = StatisticsManager()

    func applicationDidFinishLaunching(_ notification: Notification) {

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.action = #selector(togglePanel)
            button.target = self
        }

        viewModel.setStatisticsManager(statsManager)
        viewModel.menuBarUpdater = { [weak self] time, isRunning in
            self?.updateMenuBar(time: time, isRunning: isRunning)
        }

        let contentView = PopoverView(
            viewModel: viewModel,
            themeManager: themeManager,
            statsManager: statsManager,
            onToggleFullscreen: { [weak self] in self?.toggleFullscreen() }
        )

        panelWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        panelWindow.isFloatingPanel = alwaysOnTop
        panelWindow.level = alwaysOnTop ? .floating : .normal
        panelWindow.isOpaque = true
        panelWindow.backgroundColor = .clear
        panelWindow.hasShadow = false
        panelWindow.isMovableByWindowBackground = true
        panelWindow.isReleasedWhenClosed = false
        panelWindow.animationBehavior = .utilityWindow
        panelWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panelWindow.contentView = NSHostingView(rootView: contentView)

        positionWindowNearStatusItem()
    }

    @objc private func togglePanel() {
        if panelWindow.isVisible {
            panelWindow.orderOut(nil)
        } else {
            positionWindowNearStatusItem()
            panelWindow.orderFront(nil)
        }
        viewModel.updateMenuBarIcon()
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

    func toggleFullscreen() {
        if (panelWindow.screen ?? NSScreen.main) != nil {
            if panelWindow.styleMask.contains(.fullScreen) {
                panelWindow.toggleFullScreen(nil)
            } else {
                panelWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary]
                panelWindow.toggleFullScreen(nil)
            }
        }
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        panelWindow.isFloatingPanel = enabled
        panelWindow.level = enabled ? .floating : .normal
    }

    func updateMenuBar(time: String, isRunning: Bool) {
        guard let button = statusItem.button else { return }
        
        let showTimer = UserDefaults.standard.bool(forKey: "showTimerInMenuBar")
        
        // Icon always stays
        let icon = NSImage(named: "MenuBarIcon")
        icon?.size = NSSize(width: 18, height: 18)
        button.image = icon
        
        if showTimer && isRunning {
            // Show live timer to the left of icon
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.title = "\(time) "
            button.imagePosition = .imageRight
        } else {
            // Just the icon, no text
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
}
