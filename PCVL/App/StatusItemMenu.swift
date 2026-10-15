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
    private let tasks: TasksViewModel
    /// Whether window mode is active (the window is open or minimized).
    private let isWindowOpen: () -> Bool
    private let onOpenWindow: () -> Void
    private let onSwitchToPanel: () -> Void
    private let onShowTasks: () -> Void

    init(
        timer: TimerViewModel,
        themeManager: ThemeManager,
        settings: AppSettings,
        tasks: TasksViewModel,
        isWindowOpen: @escaping () -> Bool,
        onOpenWindow: @escaping () -> Void,
        onSwitchToPanel: @escaping () -> Void,
        onShowTasks: @escaping () -> Void
    ) {
        self.timer = timer
        self.themeManager = themeManager
        self.settings = settings
        self.tasks = tasks
        self.isWindowOpen = isWindowOpen
        self.onOpenWindow = onOpenWindow
        self.onSwitchToPanel = onSwitchToPanel
        self.onShowTasks = onShowTasks
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
        menu.addItem(taskItem())
        menu.addItem(durationItem("Work", .work))
        menu.addItem(durationItem("Break", .breakTime))

        menu.addItem(.separator())
        menu.addItem(submenuItem("Theme", options: themeManager.themeOptions.map(\.selection), selected: themeManager.currentTheme,
                                 title: themeManager.name(for:), action: #selector(setTheme(_:))))
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

    /// Open tasks to pick the current one from. Locked (like in the picker) while a
    /// focus session is in progress.
    private func taskItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "Task: \(tasks.activeTask?.title ?? "None")", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let none = item("No Task", action: #selector(setTask(_:)), isOn: tasks.activeTaskID == nil)
        none.isEnabled = !tasks.isSelectionLocked
        submenu.addItem(none)
        for task in tasks.openTasks {
            let entry = item(tasks.menuTitle(for: task), action: #selector(setTask(_:)), isOn: task.id == tasks.activeTaskID)
            entry.representedObject = task.id
            entry.isEnabled = !tasks.isSelectionLocked
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        submenu.addItem(item("Manage Tasks…", action: #selector(showTasks)))
        parent.submenu = submenu
        return parent
    }

    private func submenuItem<Option: Equatable>(
        _ title: String,
        options: [Option],
        selected: Option,
        title optionTitle: (Option) -> String,
        action: Selector
    ) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in options {
            let entry = item(optionTitle(option), action: action, isOn: option == selected)
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

    @objc private func showTasks() { onShowTasks() }

    @objc private func setTask(_ sender: NSMenuItem) {
        tasks.select(sender.representedObject as? UUID)
    }

    @objc private func setDuration(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? DurationChoice else { return }
        timer.setDuration(choice.duration, minutes: choice.minutes)
    }

    @objc private func setTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? ThemeSelection else { return }
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
