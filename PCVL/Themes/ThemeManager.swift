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

// MARK: - App Font

enum AppFont: String, CaseIterable, Identifiable {
    case system = "System"
    case inter = "Inter"
    
    var id: String { rawValue }
    
    func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, weightBoost: Int = 1) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight, design: design)
        case .inter:
            // Boost weight for Inter to compensate for lighter rendering
            let adjustedWeight = self.boostedWeight(weight, boost: weightBoost)
            return .custom("Inter", size: size).weight(adjustedWeight)
        }
    }
    
    func boostedWeight(_ weight: Font.Weight, boost: Int) -> Font.Weight {
        let weights: [Font.Weight] = [.thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        
        // Find current weight index
        let currentIndex: Int
        switch weight {
        case .thin: currentIndex = 0
        case .light: currentIndex = 1
        case .regular: currentIndex = 2
        case .medium: currentIndex = 3
        case .semibold: currentIndex = 4
        case .bold: currentIndex = 5
        case .heavy: currentIndex = 6
        case .black: currentIndex = 7
        default: currentIndex = 2
        }
        
        // Apply boost and clamp to valid range
        let newIndex = min(7, currentIndex + boost)
        return weights[newIndex]
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") var selectedThemeName: String = AppTheme.minimalist.rawValue {
        didSet { objectWillChange.send() }
    }
    @AppStorage("selectedFont") var selectedFontName: String = AppFont.system.rawValue {
        didSet { objectWillChange.send() }
    }
    @AppStorage("interFontWeightBoost") var interFontWeightBoost: Int = 1 {
        didSet { objectWillChange.send() }
    }

    var currentTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeName) ?? .minimalist }
        set {
            selectedThemeName = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var currentFont: AppFont {
        get { AppFont(rawValue: selectedFontName) ?? .system }
        set {
            selectedFontName = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    // Helper method to get font with automatic weight boost applied
    func getFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return currentFont.font(size: size, weight: weight, design: design, weightBoost: interFontWeightBoost)
    }

    // Font specifically for the timer display — applies weight boost
    func timerFont(size: CGFloat, weight: Font.Weight = .thin) -> Font {
        switch currentFont {
        case .system:
            return .system(size: size, weight: weight)
        case .inter:
            let adjustedWeight = currentFont.boostedWeight(weight, boost: interFontWeightBoost)
            return .custom("Inter", size: size).weight(adjustedWeight)
        }
    }
    
    func fontWeightLabel(_ boost: Int) -> String {
        switch boost {
        case 0: return "Light"
        case 1: return "Medium"
        case 2: return "Semibold"
        case 3: return "Bold"
        default: return "Custom"
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
