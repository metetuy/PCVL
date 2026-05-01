# PCVL — Pomodoro App

## Project overview
macOS menu bar popup app built with Swift and SwiftUI.
No Dock icon (LSUIElement = YES). Popup appears on menu bar click (NSPanel, not NSPopover).

## Tech stack
- Swift 5.9+
- SwiftUI
- SwiftData (local statistics storage)
- Xcode 15+
- Minimum deployment: macOS 14 (Sonoma)
- No external dependencies

## App architecture
- **AppDelegate**: NSStatusItem + NSPanel setup, event monitors, right-click context menu, font registration, menu bar icon updates
- **TimerEngine**: Pure value-type state machine — countdown + stopwatch modes, no side effects
- **TimerViewModel**: ObservableObject, drives all timer state, session recording, notifications
- **ThemeManager**: Color schemes + font management, persisted via @AppStorage
- **StatisticsManager**: SwiftData CRUD for SessionRecord models
- **SwipeMonitor** (in PopoverView): NSEvent monitor for horizontal trackpad swipe to switch tabs

## Project structure
```
PCVL/
├── App/
│   ├── PCVLApp.swift           (entry point, delegates to AppDelegate)
│   └── AppDelegate.swift       (menu bar icon, NSPanel, event handling, context menu)
├── Timer/
│   ├── TimerEngine.swift       (pure state machine: idle/running/paused/completed)
│   └── TimerViewModel.swift    (observable, orchestrates engine + stats + notifications)
├── Views/
│   ├── PopoverView.swift       (tab shell: timer/stats/settings + swipe navigation)
│   ├── TimerView.swift         (timer display, scroll wheel duration, progress line)
│   ├── StatsView.swift         (today cards, weekly bar chart, recent sessions list)
│   └── SettingsView.swift      (durations, font, theme, window toggles, data reset)
├── Themes/
│   └── ThemeManager.swift      (AppTheme enum: Minimalist/Dark/Light/Ocean/Bloom + AppFont)
├── Data/
│   └── StatisticsManager.swift (SwiftData SessionRecord, streak, weekly, today stats)
└── Fonts/
    └── Inter-VariableFont_opsz,wght.ttf
```

## Key implementation details

### Window
- NSPanel (not NSPopover), borderless, non-activating, floating
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
- Queries: today sessions, today focus minutes, current streak, weekly data (Mon–Sun), recent sessions
- Streak = consecutive days with at least one focus session counting backwards from today

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
- Do not add Dock icon or main window
- Do not use UIKit
- Do not add external packages without asking
- Do not add WidgetKit — it is not implemented and not in current scope
- SwiftUI views stay dumb — all logic belongs in ViewModels or Managers
- Comments must be in English
