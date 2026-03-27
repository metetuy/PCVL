import SwiftUI
import Combine

// MARK: - Theme Enum

enum AppTheme: String, CaseIterable, Identifiable {
    case minimalist = "Minimalist"
    case dark = "Dark"
    case light = "Light"
    case ocean = "Ocean"
    case bloom = "Bloom"

    var id: String { rawValue }
}

// MARK: - Theme Colors

struct ThemeColors {
    let background: Color
    let surface: Color
    let text: Color
    let textSecondary: Color
    let accent: Color
    let timerRing: Color
    let breakRing: Color
    let ringTrack: Color
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedThemeName: String = AppTheme.minimalist.rawValue

    var currentTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeName) ?? .minimalist }
        set {
            selectedThemeName = newValue.rawValue
            objectWillChange.send()
        }
    }

    var colors: ThemeColors {
        switch currentTheme {
        case .minimalist:
            return ThemeColors(
                background: Color(.windowBackgroundColor),
                surface: Color(.controlBackgroundColor),
                text: Color(.labelColor),
                textSecondary: Color(.secondaryLabelColor),
                accent: Color(nsColor: NSColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1)),
                timerRing: Color(nsColor: NSColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1)),
                breakRing: Color(nsColor: NSColor(red: 0.55, green: 0.65, blue: 0.6, alpha: 1)),
                ringTrack: Color(.separatorColor)
            )

        case .dark:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)),
                surface: Color(nsColor: NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1)),
                text: Color(white: 0.92),
                textSecondary: Color(white: 0.5),
                accent: Color(nsColor: NSColor(red: 0.95, green: 0.6, blue: 0.25, alpha: 1)),
                timerRing: Color(nsColor: NSColor(red: 0.95, green: 0.6, blue: 0.25, alpha: 1)),
                breakRing: Color(nsColor: NSColor(red: 0.4, green: 0.8, blue: 0.7, alpha: 1)),
                ringTrack: Color(white: 0.18)
            )

        case .light:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)),
                surface: .white,
                text: Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)),
                textSecondary: Color(nsColor: NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)),
                accent: Color(nsColor: NSColor(red: 0.3, green: 0.3, blue: 0.65, alpha: 1)),
                timerRing: Color(nsColor: NSColor(red: 0.3, green: 0.3, blue: 0.65, alpha: 1)),
                breakRing: Color(nsColor: NSColor(red: 0.25, green: 0.6, blue: 0.55, alpha: 1)),
                ringTrack: Color(nsColor: NSColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1))
            )

        case .ocean:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1)),
                surface: Color(nsColor: NSColor(red: 0.07, green: 0.12, blue: 0.22, alpha: 1)),
                text: Color(nsColor: NSColor(red: 0.88, green: 0.92, blue: 0.96, alpha: 1)),
                textSecondary: Color(nsColor: NSColor(red: 0.45, green: 0.55, blue: 0.65, alpha: 1)),
                accent: Color(nsColor: NSColor(red: 0.25, green: 0.7, blue: 0.85, alpha: 1)),
                timerRing: Color(nsColor: NSColor(red: 0.25, green: 0.7, blue: 0.85, alpha: 1)),
                breakRing: Color(nsColor: NSColor(red: 0.35, green: 0.75, blue: 0.55, alpha: 1)),
                ringTrack: Color(nsColor: NSColor(red: 0.1, green: 0.16, blue: 0.28, alpha: 1))
            )
            
            //TODO: Sude's Theme
        case .bloom:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.14, green: 0.06, blue: 0.1, alpha: 1)),
                surface: Color(nsColor: NSColor(red: 0.22, green: 0.1, blue: 0.16, alpha: 1)),
                text: Color(nsColor: NSColor(red: 0.96, green: 0.88, blue: 0.92, alpha: 1)),
                textSecondary: Color(nsColor: NSColor(red: 0.65, green: 0.45, blue: 0.55, alpha: 1)),
                accent: Color(nsColor: NSColor(red: 0.95, green: 0.4, blue: 0.55, alpha: 1)),
                timerRing: Color(nsColor: NSColor(red: 0.95, green: 0.4, blue: 0.55, alpha: 1)),
                breakRing: Color(nsColor: NSColor(red: 0.7, green: 0.45, blue: 0.8, alpha: 1)),
                ringTrack: Color(nsColor: NSColor(red: 0.26, green: 0.14, blue: 0.2, alpha: 1))
            )
        }
    }
}
