import AppKit
import SwiftUI
import Testing
@testable import PCVL

/// Renders the README screenshots into docs/screenshots from the real panel and
/// window, filled with sample data (an in-memory store, nothing of the user's).
/// Skipped in normal test runs; to refresh the images:
///
///   TEST_RUNNER_PCVL_SCREENSHOTS=1 xcodebuild test -scheme PCVL -only-testing:PCVLTests/ReadmeScreenshots
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["PCVL_SCREENSHOTS"] != nil))
struct ReadmeScreenshots {
    private static let output = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/screenshots")
    private static let preservedKeys = ["NSWindow Frame PCVLMainWindow", "windowSidebarCollapsed"]
    /// The timer reads its durations from the standard defaults; the shots use the
    /// defaults (25 / 5 min) and every test puts the user's own values back.
    private static let durationKeys = ["workDuration": 25 * 60, "breakDuration": 5 * 60]

    private let stats = StatisticsManager(inMemory: true)
    private let theme: ThemeManager
    private let settings: AppSettings
    private let timer: TimerViewModel
    private let savedDurations: [(String, Any?)]
    private let taskManager: TaskManager
    private let tasks: TasksViewModel

    init() throws {
        let defaults = UserDefaults(suiteName: "PCVLTests.Screenshots.\(UUID().uuidString)")!
        theme = ThemeManager(defaults: defaults)
        theme.currentTheme = .builtIn(.dark)
        savedDurations = Self.durationKeys.keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        for (key, seconds) in Self.durationKeys { UserDefaults.standard.set(seconds, forKey: key) }
        timer = TimerViewModel()
        settings = AppSettings(statsManager: stats, updater: Updater(defaults: defaults), defaults: defaults)
        taskManager = TaskManager(statsManager: stats, defaults: defaults)
        tasks = TasksViewModel(taskManager: taskManager, statsManager: stats, timer: timer)
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        recordSampleData()
    }

    /// Four weeks of plausible focus: a few sessions most days, spread over three tasks.
    private func recordSampleData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let titles = ["Thesis", "Portfolio site", "Reading"]
        let ids = titles.enumerated().compactMap { index, title in
            taskManager.addTask(title: title, at: today.addingTimeInterval(Double(-30 + index) * 86_400))
        }
        if let done = taskManager.addTask(title: "Weekly review", at: today.addingTimeInterval(-20 * 86_400)) {
            stats.recordSession(duration: 25 * 60, date: today.addingTimeInterval(-6 * 86_400 + 17 * 3600), type: .work, taskID: done)
            tasks.toggleDone(done)
        }

        var generator = SeededGenerator(seed: 7)
        for dayOffset in 0..<28 where dayOffset % 7 != 5 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            var hour = 9.0 + Double(Int.random(in: 0...2, using: &generator))
            for _ in 0..<Int.random(in: 2...5, using: &generator) {
                let start = day.addingTimeInterval(hour * 3600)
                // Today only up to now, so the panel's "today" stays truthful.
                guard start < Date().addingTimeInterval(-3600) else { break }
                let minutes = [25, 25, 50, 45, 30].randomElement(using: &generator)!
                stats.recordSession(duration: minutes * 60, date: start, type: .work,
                                    taskID: ids.randomElement(using: &generator))
                stats.recordSession(duration: 5 * 60, date: start.addingTimeInterval(Double(minutes) * 60), type: .shortBreak)
                hour += Double(minutes + 20) / 60
            }
        }
        tasks.select(ids.first)
    }

    private func restoreDurations() {
        for (key, value) in savedDurations { UserDefaults.standard.set(value, forKey: key) }
    }

    // MARK: - Shots

    @Test func panel() async throws {
        defer { restoreDurations() }
        let view = PopoverView(
            viewModel: timer, themeManager: theme, settings: settings,
            statsSummary: StatsSummaryViewModel(statsManager: stats, settings: settings), tasks: tasks,
            onExpand: { _ in }, onShowThemePicker: { _ in }
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 190), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        try await Task.sleep(for: .seconds(0.6))
        try save(snapshot(of: try #require(window.contentView), cornerRadius: 12), as: "panel")
        window.close()
    }

    @Test(arguments: WindowSection.allCases)
    func window(section: WindowSection) async throws {
        defer { restoreDurations() }
        let defaults = UserDefaults.standard
        let saved = Self.preservedKeys.map { ($0, defaults.object(forKey: $0)) }
        defer { for (key, value) in saved { defaults.set(value, forKey: key) } }
        defaults.set(false, forKey: "windowSidebarCollapsed")

        let controller = MainWindowController(
            timerViewModel: timer, themeManager: theme, settings: settings,
            statsSummary: StatsSummaryViewModel(statsManager: stats, settings: settings), tasksViewModel: tasks,
            analyticsViewModel: AnalyticsViewModel(statsManager: stats, settings: settings),
            taskAnalyticsViewModel: TaskAnalyticsViewModel(statsManager: stats, taskManager: taskManager),
            onSwitchedToPanel: {}
        )
        controller.show(section: section)
        let window = try #require(controller.window)
        window.setFrame(NSRect(x: 80, y: 80, width: 1080, height: 720), display: true)
        try await Task.sleep(for: .seconds(1))
        // The frame view, so the title bar and its buttons are in the picture.
        let frameView = try #require(window.contentView?.superview)
        try save(snapshot(of: frameView, cornerRadius: 16), as: "window-\(section.title.lowercased())")
        window.close()
    }

    // MARK: - Rendering

    /// The view's pixels with rounded corners and a soft drop shadow on a transparent margin.
    private func snapshot(of view: NSView, cornerRadius: CGFloat) throws -> NSBitmapImageRep {
        let content = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: content)

        let scale = CGFloat(content.pixelsWide) / view.bounds.width
        let margin: CGFloat = 40
        let size = NSSize(width: view.bounds.width + margin * 2, height: view.bounds.height + margin * 2)
        let output = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        output.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)
        let rect = NSRect(x: margin, y: margin, width: view.bounds.width, height: view.bounds.height)
        let shape = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.shadowBlurRadius = 24
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        shape.addClip()
        content.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        return output
    }

    private func save(_ image: NSBitmapImageRep, as name: String) throws {
        let data = try #require(image.representation(using: .png, properties: [:]))
        try data.write(to: Self.output.appendingPathComponent("\(name).png"))
    }
}

/// Deterministic randomness, so regenerated screenshots only change when the app does.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
