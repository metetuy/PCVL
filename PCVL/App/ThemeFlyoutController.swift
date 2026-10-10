import AppKit
import SwiftUI

// MARK: - Theme Flyout Controller

/// Shows the theme list in its own borderless panel that pops out beside the main
/// panel (like a submenu), rather than rendering inline in the popup. Closes on any
/// click outside it.
@MainActor
final class ThemeFlyoutController {
    private let themeManager: ThemeManager
    private(set) var window: NSPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }

    /// `anchorRect` is the theme button's frame in the main panel's coordinate space.
    func show(beside mainPanel: NSWindow, anchorRect: CGRect) {
        // Deferred: creating and ordering a new panel synchronously from a
        // SwiftUI button action re-enters AppKit's layout pass mid-tap.
        DispatchQueue.main.async { [weak self] in
            self?.present(beside: mainPanel, anchorRect: anchorRect)
        }
    }

    func hide() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        window?.orderOut(nil)
        window = nil
    }

    private func present(beside mainPanel: NSWindow, anchorRect: CGRect) {
        hide()

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

        let mainFrame = mainPanel.frame
        let buttonTopScreenY = mainFrame.origin.y + mainFrame.height - anchorRect.minY
        var originX = mainFrame.origin.x + mainFrame.width + 6
        var originY = buttonTopScreenY - height

        if let screenFrame = mainPanel.screen?.visibleFrame {
            if originX + width > screenFrame.maxX {
                originX = mainFrame.origin.x - width - 6
            }
            originY = min(originY, screenFrame.maxY - height)
            originY = max(originY, screenFrame.minY)
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        panel.orderFront(nil)
        window = panel

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window != self.window {
                self.hide()
            }
            return event
        }
    }
}
