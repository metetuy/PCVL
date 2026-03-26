# PCVL — Pomodoro App

## Project overview
macOS menu bar popup app built with Swift and SwiftUI.
No Dock icon (LSUIElement = YES). Popup appears on menu bar click.

## Tech stack
- Swift 5.9+
- SwiftUI
- SwiftData (local statistics storage)
- WidgetKit (widget extension)
- Xcode 15+
- Minimum deployment: macOS 14 (Sonoma)

## App architecture
- AppDelegate: NSStatusItem + NSPopover setup
- TimerViewModel: ObservableObject, drives all timer state
- TimerEngine: pure timer logic, countdown + stopwatch modes
- ThemeManager: color schemes, persisted via @AppStorage
- StatisticsManager: SwiftData CRUD for session records

## Project structure
PCVL/
├── App/
│   ├── PCVLApp.swift
│   └── AppDelegate.swift
├── Timer/
│   ├── TimerViewModel.swift
│   └── TimerEngine.swift
├── Views/
│   ├── PopoverView.swift
│   ├── StatsView.swift
│   └── SettingsView.swift
├── Themes/
│   └── ThemeManager.swift
├── Data/
│   └── StatisticsManager.swift
└── Widget/
    └── PomodoroWidget.swift

## Features (current scope)
- Countdown timer (Pomodoro: 25min work, 5min break)
- Chronometer (stopwatch) mode
- Multiple themes (minimalist, dark, light, custom)
- Local statistics: sessions completed, total focus time, streaks
- macOS widget showing current timer state
- Menu bar icon updates with timer state

## Code style
- MVVM pattern throughout
- SwiftUI views are dumb — all logic in ViewModels
- No third party dependencies
- Comments in English

## What NOT to do
- Do not add Dock icon or main window
- Do not use UIKit
- Do not add external packages without asking
