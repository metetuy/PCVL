import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case minimalist = "Minimalist"
    case dark = "Dark"
    case light = "Light"
    case ocean = "Ocean"

    var id: String { rawValue }
}

struct ThemeColors {
    let background: Color
    let surface: Color
    let primary: Color
    let secondary: Color
    let text: Color
    let textSecondary: Color
    let accent: Color
    let timerRing: Color
    let breakRing: Color
}

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
                primary: .accentColor,
                secondary: .gray,
                text: Color(.labelColor),
                textSecondary: Color(.secondaryLabelColor),
                accent: .blue,
                timerRing: .blue,
                breakRing: .green
            )
        case .dark:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)),
                surface: Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)),
                primary: .orange,
                secondary: .gray,
                text: .white,
                textSecondary: Color(white: 0.6),
                accent: .orange,
                timerRing: .orange,
                breakRing: .mint
            )
        case .light:
            return ThemeColors(
                background: Color(white: 0.97),
                surface: .white,
                primary: .indigo,
                secondary: Color(white: 0.7),
                text: Color(white: 0.1),
                textSecondary: Color(white: 0.4),
                accent: .indigo,
                timerRing: .indigo,
                breakRing: .teal
            )
        case .ocean:
            return ThemeColors(
                background: Color(nsColor: NSColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1)),
                surface: Color(nsColor: NSColor(red: 0.08, green: 0.15, blue: 0.28, alpha: 1)),
                primary: .cyan,
                secondary: Color(nsColor: NSColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 1)),
                text: .white,
                textSecondary: Color(nsColor: NSColor(red: 0.6, green: 0.7, blue: 0.8, alpha: 1)),
                accent: .cyan,
                timerRing: .cyan,
                breakRing: Color(nsColor: NSColor(red: 0.4, green: 0.8, blue: 0.6, alpha: 1))
            )
        }
    }
}
