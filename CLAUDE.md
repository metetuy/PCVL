# PCVL — Pomodoro App

## Project overview
macOS menu bar popup app built with Swift and SwiftUI.
No Dock icon (LSUIElement = YES). Popup appears on menu bar click (NSPanel, not NSPopover).
The panel stays concise; "Expand for details" opens an optional resizable desktop window
(Focus / Tasks / Analytics / Settings) that supports native full screen.

## Tech stack
- Swift 5.9+
- SwiftUI
- SwiftData (local statistics storage)
- Xcode 15+
- Minimum deployment: macOS 14 (Sonoma)
- No external dependencies

## App architecture
- **AppDelegate**: NSStatusItem + NSPanel (`KeyablePanel`, can become key so text fields take typing) setup, outside-click monitors, font registration, menu bar icon updates, panel ↔ window transitions, observes `AppSettings` (always on top, timer in menu bar)
- **AppSettings**: ObservableObject owning the shared preferences (always on top, timer in menu bar, stats time unit) and the shared actions (reset statistics with confirmation, export, quit). The panel's settings tab, the window's settings screen and the context menu all bind to it
- **StatusItemMenu**: Builds the right-click context menu and handles its actions through the same models
- **ThemeFlyoutController**: The theme picker panel that pops out beside the main panel
- **MainWindowController**: Lazily creates the titled, resizable NSWindow (frame autosaved, native full screen as part of window mode); `WindowState` holds section / full screen / sidebar collapsed / theme editor draft
- **TimerEngine**: Pure value-type state machine — countdown + stopwatch modes, no side effects; elapsed time is measured against a wall-clock `Date` passed in, so late/throttled ticks never lose time
- **TimerViewModel**: ObservableObject, drives all timer state, session recording, notifications
- **ThemeManager**: Color schemes + font management, `@Published` properties persisted to UserDefaults; owns custom themes (`customThemes`, JSON under `customThemes`) and the current `ThemeSelection` (built-in or custom); `themeOptions` lists both for every theme picker
- **ThemeEditorViewModel**: Draft of a custom theme (name, `ThemePalette`, selected color role), validation, save (also applies it) / delete — surface-independent so the panel can reuse it
- **StatisticsManager**: SwiftData CRUD for SessionRecord models, date-range fetches, cached focus days for streaks; `didChange` fires after every save and when the day rolls over (also on wake / time zone change)
- **StatsAnalyzer**: Pure aggregation (periods, buckets, streaks, distributions) — no side effects
- **AnalyticsViewModel**: ObservableObject for the window's analytics — range, period navigation, minutes/hours unit; only recomputes while active (set by MainWindowController), otherwise marks itself stale
- **TaskManager**: SwiftData CRUD for `FocusTask` (same container as sessions) and the current task (`activeTaskID`, persisted); clears it when that task is checked off or deleted
- **TasksViewModel**: ObservableObject for every task surface (tasks screen, task picker, context menu) — open/done lists with totals, current task, `isSelectionLocked` while a focus session is in progress
- **TaskAnalyzer**: Pure all-time aggregation per task (totals, sessions, avg/longest, first/last worked, active days, share) and the hour-block unit — no periods, no hour splitting
- **TaskAnalyticsViewModel**: ObservableObject for the analytics screen's task cards, the selected card's sessions and assigning sessions to tasks; like AnalyticsViewModel only recomputes while active
- **StatsSummaryViewModel**: Today + this week, shared by the panel's stats tab and the focus screen footer — the single source for "today"
- **SwipeMonitor** (in PopoverView): NSEvent monitor for horizontal trackpad swipe to switch tabs

## Project structure
```
PCVL/
├── App/
│   ├── PCVLApp.swift              (entry point, delegates to AppDelegate)
│   ├── AppDelegate.swift          (menu bar icon, NSPanel, event handling)
│   ├── AppSettings.swift          (shared preferences + reset/export/quit actions)
│   ├── StatusItemMenu.swift       (right-click context menu)
│   └── ThemeFlyoutController.swift(theme picker flyout panel, "Create Theme…" → window editor)
├── Window/                        (optional desktop window, one file per screen)
│   ├── MainWindowController.swift (NSWindow setup + delegate, WindowSection, WindowState)
│   ├── MainWindowView.swift       (collapsible sidebar, top bar: sidebar / full screen / panel)
│   ├── FocusScreen.swift          (clean, scalable timer + task picker)
│   ├── TasksScreen.swift          (add, pick current, check off, rename, delete; totals per task)
│   ├── AnalyticsScreen.swift      (tasks section first, then time: totals, chart + sessions, distributions, insights last)
│   ├── TaskAnalyticsSection.swift (task cards with hour blocks, sessions behind the selected card, SessionTaskMenu)
│   ├── SettingsScreen.swift       (durations, theme previews + Create Theme tile, font, panel behavior, data)
│   └── ThemeEditorScreen.swift    (create / edit a custom theme, shown in place of the settings)
├── Views/                         (menu bar panel, 300x190)
│   ├── PopoverView.swift          (tab shell: timer/stats/settings + swipe navigation)
│   ├── ExpandHandle.swift         (hover "Expand for details" → opens the window)
│   ├── TimerView.swift            (compact timer + task chip)
│   ├── TasksView.swift            (open tasks: add, pick current, check off)
│   ├── StatsView.swift            (today, this week chart, recent sessions)
│   ├── SettingsView.swift         (durations, font, theme flyout, window toggles, reset)
│   ├── ThemeFlyoutView.swift, HoverEffect.swift, SpringButtonStyle.swift
├── Components/                    (shared by panel and window)
│   ├── TimerControls.swift        (mode toggle, control row, primary/circle buttons, progress line, scroll-to-adjust)
│   ├── SettingsComponents.swift   (reset confirmation alert, duration stepper)
│   ├── TaskComponents.swift       (TaskPicker chip + menu, TaskAddField, TaskList / TaskRow — compact in the panel)
│   ├── StatsComponents.swift      (cards, session row, segmented control, Swift Charts bar charts)
│   ├── ThemeComponents.swift      (ThemePreview, ThemeRoleList, ThemeColorPicker: spectrum, hue, hex, swatches)
│   └── ThemedBackground.swift     (per-theme radial gradient)
├── Timer/
│   ├── TimerEngine.swift          (pure state machine: idle/running/paused/completed)
│   └── TimerViewModel.swift       (observable, orchestrates engine + stats + notifications)
├── Themes/
│   ├── ThemeManager.swift         (AppTheme enum + AppFont, `colors(for:)` for previews, custom themes)
│   ├── CustomTheme.swift          (RGBColor, ThemeColorRole, ThemePalette, CustomTheme, ThemeSelection, ThemeOption)
│   └── ThemeEditorViewModel.swift (custom theme draft + swatches)
├── Data/
│   ├── StatisticsManager.swift    (SwiftData SessionRecord, range fetches, snapshot(range:offset:))
│   ├── TaskManager.swift          (SwiftData FocusTask, TaskItem, current task)
│   ├── TasksViewModel.swift       (task state for all surfaces)
│   ├── StatsAnalytics.swift       (StatsRange, StatsTimeUnit, StatsSnapshot, StatsAnalyzer)
│   ├── TaskAnalytics.swift        (TaskSummary, TaskAnalyzer — sessions are `StatsSessionItem`)
│   ├── TaskAnalyticsViewModel.swift(analytics tasks section state + assigning)
│   ├── StatsFormatting.swift      (StatsFormat display strings)
│   ├── AnalyticsViewModel.swift   (window analytics state)
│   └── StatsSummaryViewModel.swift(panel stats state)
└── Fonts/
    └── Inter-VariableFont_opsz,wght.ttf
PCVLTests/                         (Swift Testing, hosted in the app; run with ⌘U or `xcodebuild test -scheme PCVL`)
├── TimerEngineTests.swift, TimerViewModelTests.swift, StatsAnalyzerTests.swift, StatsSummaryTests.swift, TaskTests.swift, TaskAnalyzerTests.swift, ThemeTests.swift
└── MainWindowTests.swift          (real window + synthesized clicks: sidebar button, full screen, sizing, theme delete confirmation)
```

## Key implementation details

### Panel
- NSPanel (not NSPopover), borderless, non-activating, floating, fixed 300x190
- `KeyablePanel` overrides `canBecomeKey` (borderless windows refuse it) and is made key when shown, so the tasks tab's text fields take typing
- Positioned dynamically below the status bar button
- "Always on Top" elevates window level to `.statusBar`
- Auto-close on outside click via global NSEvent monitor (disabled when Always on Top active, regardless of other settings)

### Timer
- `TimerEngine` is a value type (struct); `TimerViewModel` owns it and fires a 1s `Timer` that only refreshes the display — time comes from the clock (`TimerViewModel(now:)` is injectable for tests)
- Skipping or resetting records whatever ran of the current phase (focus, break or stopwatch)
- Modes: `countDown` (work/break) | `countUp` (stopwatch)
- States: `idle` | `running` | `paused` | `completed`
- Duration config: work 5–480 min (default 25), break 1–30 min (default 5); the context menu offers `AdjustableDuration.menuPresets` plus the current value, disabled while a session runs
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

### Custom themes
- `CustomTheme`: id, name, `ThemePalette` of 7 `RGBColor`s (stored as "#RRGGBB"); `timerRing` always follows `accent`
- Selection persists under `selectedTheme`: a built-in's raw value (unchanged) or `custom:<uuid>`; a missing or deleted custom theme falls back to Minimalist
- Names are unique among all themes, ignoring case; palettes follow the same rules as built-ins (`ThemePalette.problems`)
- Window: Settings › Theme grid ends with a "Create Theme" tile; custom tiles edit via hover pencil or right click (Edit / Delete); any tile → right click "New Theme from …". The editor replaces the settings screen (draft held in `WindowState.themeEditor`, so it survives switching sections): live `ThemePreview` of the panel (break phase while editing the Break color), color list, picker for the selected color; Revert restores the name and colors the draft was opened with (enabled once something differs by hex); Save (⌘S) applies the theme, Esc cancels. Native controls, laid out like a macOS dialog: Delete + Revert left, Cancel + prominent Save (accent tint) right; Delete takes two steps, no animation: Delete (with a trash icon) turns into a red "Are you sure?" bar with a white trash circle at its start, and only the circle deletes (a double click lands on the text). It stays armed regardless of hover until the next click: anywhere but the circle disarms (local mouse-up monitor, installed after the arming click). The editor sets `colorScheme` from `ThemeManager.colorScheme` (theme background luminance; nil = system for Minimalist) so native controls suit the theme
- Panel: custom themes are selectable in the flyout and the context menu; the flyout's fixed "Create Theme…" row enters window mode straight into a new draft (`MainWindowController.showThemeEditor`) — there is no editor in the panel
- The selected theme tile is marked by its accent border and bold name only (no checkmark)

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
- Every surface derives "today" from the week snapshot (hour-split), never from whole sessions by start date
- Streak = consecutive days with at least one focus session counting backwards from today; longest streak also tracked
- Charts use Swift Charts (system framework) with hover readouts

### Tasks
- `FocusTask`: id, title, createdAt, completedAt (nil = open); `SessionRecord.task` is optional, delete rule `.nullify` (deleting a task keeps its sessions as untagged focus time)
- A task's time is never stored — it is summed from its linked sessions, so it always agrees with the statistics (and reset statistics zeroes it)
- `TimerViewModel` captures the current task when a focus/stopwatch session starts (`sessionTaskID`); breaks are never linked
- The current task is locked while a focus session runs or is paused; free during breaks and between sessions
- The first task added while none is current becomes current; checking off or deleting the current task clears it
- `deleteAllSessions` deletes records one by one — a batch delete bypasses the context and leaves loaded tasks listing deleted sessions
- Add bar (`TaskAddField`, shared by panel and window): dashed circle in the rows' check box column, + button on the right that springs in on hover (opacity/scale only — it always keeps its space so nothing moves); Return adds too
- Rows (shared by panel and window): click = make current, circle = check off; hovering shows rename (pencil) and delete (trash) — in compact panel rows they replace the time; renaming shows save (✓) / cancel (✕), Return / Esc do the same; right click has the same actions
- Panel: tasks tab (open tasks only, compact rows); task chip in the timer's top row (only once tasks exist) whose "Manage Tasks…" switches to that tab; context menu: "Task:" submenu. Done tasks are shown in the window only

### Task analytics
- Analytics opens with Tasks (all time): one card per task — total = plain sum of its sessions, independent of the selected range and never split by hour/day — drawn as hour blocks (one unit for all cards, `TaskAnalyzer.blockUnitHours`, largest total ≤ 60 blocks). Order: open (most focus first, then not started), done (recently finished first), "No task" last (untagged focus, e.g. sessions from before tasks)
- Clicking a card lists the sessions behind its total (avg, longest, active days, share); clicking again closes it
- Done tasks show "Created … · Done …" (tasks screen, cards); menus add the creation day to done tasks and to tasks sharing a title (`TasksViewModel.menuTitle(for:among:)`)
- Assigning: "No task" sessions → "Assign all to a task…" (confirmation) via `StatisticsManager.assignUntaggedSessions(toTask:)`; any focus session in the time section's list → right click → Task ▸ (`assignSession(_:toTask:)`). Breaks are never assigned
- The time section below is unchanged; session rows show their task

### Desktop window
- Window mode = window visible or minimized. While active the panel is disabled: the menu bar icon brings the window forward, the context menu offers "Show PCVL Window" / "Switch to Menu Bar Panel"
- Entered from the panel's hover expand handle (matching section) or the context menu; always via `AppDelegate.enterWindowMode`, which closes the panel first
- Titled, resizable, `.fullScreenPrimary`, empty `.unifiedCompact` toolbar (taller title bar), min 720x500, frame autosaved as "PCVLMainWindow"
- Top bar: sidebar toggle (⌃⌘S) left; full screen toggle (⌃⌘F) and "switch to panel" right. It is an overlay drawn into the title bar's safe area; the content itself respects that safe area. Never put a ScrollView under a container that ignores the top safe area — its NSScrollView extends up under the top bar and swallows the clicks
- The window alone owns its size (`contentMinSize`, `sizingOptions = []`); no SwiftUI animation inside the full screen delegate callbacks (it makes NSHostingView fight AppKit's resize and crashes with an Update Constraints loop)
- Full screen is an extension of window mode: entering collapses the sidebar to icons, exiting restores it; closing or switching to the panel exits full screen first
- Full screen auto-hides the toolbar with the menu bar (`willUseFullScreenPresentationOptions`); otherwise AppKit pins an opaque toolbar strip over the top bar
- Sidebar: Focus / Tasks / Analytics / Settings (⌘1–4), live session status; collapsible to icons (windowed preference persisted as `windowSidebarCollapsed`); ⌘W closes
- Focus screen: Space starts/pauses, scroll over the time adjusts duration when idle

### Tab navigation
- Tabs: timer | tasks | stats | settings
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
- Tasks: sessions count toward a current task; per-task time and sessions; task in JSON export

## What NOT to do
- Do not add a Dock icon; the desktop window is opt-in from the panel, the app stays menu-bar first
- Do not use UIKit
- Do not add external packages without asking
- Do not add WidgetKit — it is not implemented and not in current scope
- SwiftUI views stay dumb — all logic belongs in ViewModels or Managers
- Containers that only pass `TimerViewModel` down (PopoverView, MainWindowView, settings screens) hold it as a plain `let`; only views that display live time observe it, so a running timer doesn't re-render whole screens every second
- Persisted preference keys live in their owner (`AppSettings`, `ThemeManager`, `TimerViewModel`, `AnalyticsViewModel`) — no raw keys or `@AppStorage` in views
- Theme palettes: `ringTrack` must differ from `background` and `surface`, `accent` from `textSecondary`
- Comments must be in English
