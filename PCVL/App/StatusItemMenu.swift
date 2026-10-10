import AppKit

// MARK: - Status Item Menu

/// Builds the status item's right-click menu and handles its actions. Every item
/// writes through the same models the panel and the window use (`TimerViewModel`,
/// `ThemeManager`, `AppSettings`), so the three surfaces stay in sync.
@MainActor
final class StatusItemMenu: NSObject {
    private let timer: TimerViewModel
    private let themeManager: ThemeManager
    private let settings: AppSettings
    /// Whether window mode is active (the window is open or minimized).
    private let isWindowOpen: () -> Bool
    private let onOpenWindow: () -> Void
    private let onSwitchToPanel: () -> Void

    init(
        timer: TimerViewModel,
        themeManager: ThemeManager,
        settings: AppSettings,
        isWindowOpen: @escaping () -> Bool,
        onOpenWindow: @escaping () -> Void,
        onSwitchToPanel: @escaping () -> Void
    ) {
        self.timer = timer
        self.themeManager = themeManager
        self.settings = settings
        self.isWindowOpen = isWindowOpen
        self.onOpenWindow = onOpenWindow
        self.onSwitchToPanel = onSwitchToPanel
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()

        if isWindowOpen() {
            menu.addItem(item("Show PCVL Window", action: #selector(openWindow)))
            menu.addItem(item("Switch to Menu Bar Panel", action: #selector(switchToPanel)))
        } else {
            menu.addItem(item("Open PCVL Window", action: #selector(openWindow)))
        }

        menu.addItem(.separator())
        menu.addItem(durationItem("Work", .work))
        menu.addItem(durationItem("Break", .breakTime))

        menu.addItem(.separator())
        menu.addItem(submenuItem("Theme", options: AppTheme.allCases, selected: themeManager.currentTheme,
                                 title: \.rawValue, action: #selector(setTheme(_:))))
        menu.addItem(.separator())
        menu.addItem(submenuItem("Font", options: AppFont.allCases, selected: themeManager.currentFont,
                                 title: \.rawValue, action: #selector(setFont(_:))))

        menu.addItem(.separator())
        menu.addItem(item("Always on Top", action: #selector(toggleAlwaysOnTop), isOn: settings.alwaysOnTop))
        menu.addItem(item("Timer in Menu Bar", action: #selector(toggleMenuBarTimer), isOn: settings.showTimerInMenuBar))

        menu.addItem(.separator())
        menu.addItem(item("Reset Statistics…", action: #selector(resetStatistics)))

        menu.addItem(.separator())
        menu.addItem(item("Quit PCVL", action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    // MARK: - Items

    private func item(_ title: String, action: Selector, isOn: Bool = false, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.state = isOn ? .on : .off
        return item
    }

    /// Duration presets plus the current value when it is not one of them. Locked
    /// (like everywhere else) while a session is in progress.
    private func durationItem(_ label: String, _ duration: TimerViewModel.AdjustableDuration) -> NSMenuItem {
        let current = timer.durationMinutes(for: duration)
        let parent = NSMenuItem(title: "\(label): \(current) min", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for minutes in Set(duration.menuPresets + [current]).sorted() {
            let entry = item("\(minutes) min", action: #selector(setDuration(_:)), isOn: minutes == current)
            entry.representedObject = DurationChoice(duration: duration, minutes: minutes)
            entry.isEnabled = timer.isIdle
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    private func submenuItem<Option: Equatable>(
        _ title: String,
        options: [Option],
        selected: Option,
        title optionTitle: KeyPath<Option, String>,
        action: Selector
    ) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in options {
            let entry = item(option[keyPath: optionTitle], action: action, isOn: option == selected)
            entry.representedObject = option
            submenu.addItem(entry)
        }
        parent.submenu = submenu
        return parent
    }

    private struct DurationChoice {
        let duration: TimerViewModel.AdjustableDuration
        let minutes: Int
    }

    // MARK: - Actions

    @objc private func openWindow() { onOpenWindow() }

    @objc private func switchToPanel() { onSwitchToPanel() }

    @objc private func setDuration(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? DurationChoice else { return }
        timer.setDuration(choice.duration, minutes: choice.minutes)
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? AppTheme else { return }
        themeManager.currentTheme = theme
    }

    @objc private func setFont(_ sender: NSMenuItem) {
        guard let font = sender.representedObject as? AppFont else { return }
        themeManager.currentFont = font
    }

    @objc private func toggleAlwaysOnTop() { settings.alwaysOnTop.toggle() }

    @objc private func toggleMenuBarTimer() { settings.showTimerInMenuBar.toggle() }

    @objc private func resetStatistics() { settings.confirmResetStatistics() }

    @objc private func quit() { settings.quit() }
}
