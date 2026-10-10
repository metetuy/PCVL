# PCVL — Pomodoro App

## Project overview
macOS menu bar popup app built with Swift and SwiftUI.
No Dock icon (LSUIElement = YES). Popup appears on menu bar click (NSPanel, not NSPopover).
The panel stays concise; "Expand for details" opens an optional resizable desktop window
(Focus / Analytics / Settings) that supports native full screen.

## Tech stack
- Swift 5.9+
- SwiftUI
- SwiftData (local statistics storage)
- Xcode 15+
- Minimum deployment: macOS 14 (Sonoma)
- No external dependencies

## App architecture
- **AppDelegate**: NSStatusItem + NSPanel setup, event monitors, right-click context menu, font registration, menu bar icon updates, panel ↔ window transitions, observes `alwaysOnTop` / `showTimerInMenuBar` defaults
- **MainWindowController**: Lazily creates the titled, resizable NSWindow (frame autosaved, native full screen)
- **TimerEngine**: Pure value-type state machine — countdown + stopwatch modes, no side effects
- **TimerViewModel**: ObservableObject, drives all timer state, session recording, notifications
- **ThemeManager**: Color schemes + font management, persisted via @AppStorage
- **StatisticsManager**: SwiftData CRUD for SessionRecord models, date-range fetches
- **StatsAnalyzer**: Pure aggregation (periods, buckets, streaks, distributions) — no side effects
- **AnalyticsViewModel**: ObservableObject for the window's analytics — range, period navigation, minutes/hours unit
- **StatsSummaryViewModel**: ObservableObject for the panel's concise stats (today + this week)
- **SwipeMonitor** (in PopoverView): NSEvent monitor for horizontal trackpad swipe to switch tabs

## Project structure
```
PCVL/
├── App/
│   ├── PCVLApp.swift              (entry point, delegates to AppDelegate)
│   └── AppDelegate.swift          (menu bar icon, NSPanel, event handling, context menu)
├── Window/                        (optional desktop window, one file per screen)
│   ├── MainWindowController.swift (NSWindow setup, WindowSection, WindowNavigation)
│   ├── MainWindowView.swift       (sidebar shell, session status, collapse to menu bar)
│   ├── FocusScreen.swift          (clean, scalable timer)
│   ├── AnalyticsScreen.swift      (ranges, charts, insights, sessions)
│   └── SettingsScreen.swift       (durations, theme previews, font, panel behavior, data)
├── Views/                         (menu bar panel, 300x190)
│   ├── PopoverView.swift          (tab shell: timer/stats/settings + swipe navigation)
│   ├── ExpandHandle.swift         (hover "Expand for details" → opens the window)
│   ├── TimerView.swift            (compact timer)
│   ├── StatsView.swift            (today, this week chart, recent sessions)
│   ├── SettingsView.swift         (durations, font, theme flyout, window toggles, reset)
│   ├── ThemeFlyoutView.swift, HoverEffect.swift, SpringButtonStyle.swift
├── Components/                    (shared by panel and window)
│   ├── TimerControls.swift        (mode toggle, primary/circle buttons, progress line, scroll-to-adjust)
│   ├── StatsComponents.swift      (cards, session row, segmented control, Swift Charts bar charts)
│   └── ThemedBackground.swift     (per-theme radial gradient)
├── Timer/
│   ├── TimerEngine.swift          (pure state machine: idle/running/paused/completed)
│   └── TimerViewModel.swift       (observable, orchestrates engine + stats + notifications)
├── Themes/
│   └── ThemeManager.swift         (AppTheme enum + AppFont, `colors(for:)` for previews)
├── Data/
│   ├── StatisticsManager.swift    (SwiftData SessionRecord, range fetches, snapshot(range:offset:))
│   ├── StatsAnalytics.swift       (StatsRange, StatsTimeUnit, StatsSnapshot, StatsAnalyzer)
│   ├── StatsFormatting.swift      (StatsFormat display strings)
│   ├── AnalyticsViewModel.swift   (window analytics state)
│   └── StatsSummaryViewModel.swift(panel stats state)
└── Fonts/
    └── Inter-VariableFont_opsz,wght.ttf
```

## Key implementation details

### Panel
- NSPanel (not NSPopover), borderless, non-activating, floating, fixed 300x190
- Positioned dynamically below the status bar button
- "Always on Top" elevates window level to `.statusBar`
- Auto-close on outside click via global NSEvent monitor (disabled when Always on Top active)

### Timer
- `TimerEngine` is a value type (struct); `TimerViewModel` owns it and fires a 1s `Timer`
- Modes: `countDown` (work/break) | `countUp` (stopwatch)
- States: `idle` | `running` | `paused` | `completed`
- Duration config: work 5–480 min (default 25), break 1–30 min (default 5)
- Scroll wheel over time display adjusts duration when idle (±5 min work, ±1 min break)
- Haptic feedback fires every 80ms during scroll

### Themes — AppTheme enum
| Theme      | Background | Accent  |
|------------|-----------|---------|
| Minimalist | system     | #595960 |
| Dark       | #141418    | #F29640 |
| Light      | #F7F7FB    | #4D4DA6 |
| Ocean      | #0A1429    | #40B3D9 |
| Bloom      | #241A28    | #F26589 |

### Fonts
- `AppFont.system` — native system font
- `AppFont.inter` — "Inter" variable font, with font-weight boost (0–3 levels) to match system weight feel
- `monospacedTimer` toggle enables slashed-zero rendering in time display

### Statistics (SwiftData)
- `SessionRecord`: duration (Int seconds), date, type ("work"/"break"/"stopwatch")
- Ranges: Day (hourly bars) | Week (Mon–Sun) | Month | Year (monthly) | All (monthly, yearly beyond 3 years), with ‹ › period navigation
- Time unit toggle: minutes or hours, persisted in UserDefaults (`statsTimeUnit`, `statsRange`)
- Sessions are split at hour boundaries when aggregating, so long/overnight sessions land in the right buckets
- Snapshot: totals per type, daily average, avg/longest session, best day, active days, peak hour/weekday, focus share, change vs previous period
- Streak = consecutive days with at least one focus session counting backwards from today; longest streak also tracked
- Charts use Swift Charts (system framework) with hover readouts

### Desktop window
- Opened from the panel's hover expand handle (on the matching section) or "Open PCVL Window" in the context menu; the panel closes
- Titled, resizable, `.fullScreenPrimary`, min 720x500, frame autosaved as "PCVLMainWindow"
- Sidebar: Focus / Analytics / Settings (⌘1–3), live session status, "Collapse to menu bar" (closes window, shows panel); ⌘W closes
- Focus screen: Space starts/pauses, scroll over the time adjusts duration when idle

### Tab navigation
- Tabs: timer | stats | settings
- Switchable via tab bar icons or horizontal trackpad swipe (threshold 30px)
- `SwipeMonitor` uses NSViewRepresentable + local NSEvent monitor

## Features implemented
- Countdown timer (work + break phases, skip buttons)
- Stopwatch mode
- Configurable durations via SettingsView and right-click context menu
- 5 color themes, 2 fonts, font weight boost, slashed zero
- Progress line animation (left-to-right fill)
- Menu bar icon updates; optional timer countdown in menu bar text
- Session recording on completion or manual end
- Statistics: today sessions/minutes, streak, weekly chart, recent sessions list
- Completion sound ("Funk") + UNUserNotification
- Always on Top window toggle
- Reset all statistics with confirmation

## What NOT to do
- Do not add a Dock icon; the desktop window is opt-in from the panel, the app stays menu-bar first
- Do not use UIKit
- Do not add external packages without asking
- Do not add WidgetKit — it is not implemented and not in current scope
- SwiftUI views stay dumb — all logic belongs in ViewModels or Managers
- Comments must be in English
