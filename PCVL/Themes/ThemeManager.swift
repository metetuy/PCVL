import SwiftUI
import Combine

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case minimalist = "Minimalist"
    case dark = "Dark"
    case light = "Light"
    case ocean = "Ocean"
    case bloom = "Bloom"
    
    // New themes
    case roseDark = "Rose Dark"
    case roseLight = "Rose Light"
    case pinkSoft = "Pink Soft"
    case navyBlue = "Navy Blue"
    case slateBlue = "Slate Blue"
    case teaGreen = "Tea Green"
    case slateDark = "Slate Dark"
    case warmEarth = "Warm Earth"
    case navyGold = "Navy Gold"
    case lightBlue = "Light Blue"
    case charcoalLight = "Charcoal Light"
    case creamTeal = "Cream Teal"
    case redNavy = "Red Navy"

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

        case .roseDark:
            return ThemeColors(
                background: Color(hex: "#880d1e"),
                surface: Color(hex: "#dd2d4a"),
                text: Color(hex: "#f49cbb"),
                textSecondary: Color(hex: "#cbeef3"),
                accent: Color(hex: "#f26a8d"),
                timerRing: Color(hex: "#f26a8d"),
                breakRing: Color(hex: "#cbeef3"),
                ringTrack: Color(hex: "#5a0817")
            )

        case .roseLight:
            return ThemeColors(
                background: Color(hex: "#ffe5ec"),
                surface: Color(hex: "#ffc2d1"),
                text: Color(hex: "#880d1e"),
                textSecondary: Color(hex: "#dd2d4a"),
                accent: Color(hex: "#fb6f92"),
                timerRing: Color(hex: "#fb6f92"),
                breakRing: Color(hex: "#ff8fab"),
                ringTrack: Color(hex: "#ffb3c6")
            )

        case .pinkSoft:
            return ThemeColors(
                background: Color(hex: "#ffc2d1"),
                surface: Color(hex: "#ffb3c6"),
                text: Color(hex: "#dd2d4a"),
                textSecondary: Color(hex: "#f26a8d"),
                accent: Color(hex: "#fb6f92"),
                timerRing: Color(hex: "#fb6f92"),
                breakRing: Color(hex: "#ffe5ec"),
                ringTrack: Color(hex: "#ff8fab")
            )

        case .navyBlue:
            return ThemeColors(
                background: Color(hex: "#0d1b2a"),
                surface: Color(hex: "#1b263b"),
                text: Color(hex: "#e0e1dd"),
                textSecondary: Color(hex: "#778da9"),
                accent: Color(hex: "#415a77"),
                timerRing: Color(hex: "#415a77"),
                breakRing: Color(hex: "#778da9"),
                ringTrack: Color(hex: "#0d1b2a")
            )

        case .slateBlue:
            return ThemeColors(
                background: Color(hex: "#0d1321"),
                surface: Color(hex: "#1d2d44"),
                text: Color(hex: "#f0ebd8"),
                textSecondary: Color(hex: "#748cab"),
                accent: Color(hex: "#3e5c76"),
                timerRing: Color(hex: "#3e5c76"),
                breakRing: Color(hex: "#748cab"),
                ringTrack: Color(hex: "#0d1321")
            )

        case .teaGreen:
            return ThemeColors(
                background: Color(hex: "#bee9e8"),
                surface: Color(hex: "#62b6cb"),
                text: Color(hex: "#1b4965"),
                textSecondary: Color(hex: "#5fa8d3"),
                accent: Color(hex: "#1b4965"),
                timerRing: Color(hex: "#1b4965"),
                breakRing: Color(hex: "#5fa8d3"),
                ringTrack: Color(hex: "#cae9ff")
            )

        case .slateDark:
            return ThemeColors(
                background: Color(hex: "#110f11"),
                surface: Color(hex: "#152635"),
                text: Color(hex: "#b5cdcd"),
                textSecondary: Color(hex: "#788abb"),
                accent: Color(hex: "#596d83"),
                timerRing: Color(hex: "#596d83"),
                breakRing: Color(hex: "#788abb"),
                ringTrack: Color(hex: "#110f11")
            )

        case .warmEarth:
            return ThemeColors(
                background: Color(hex: "#ed6a5a"),
                surface: Color(hex: "#f4f1bb"),
                text: Color(hex: "#5ca4a9"),
                textSecondary: Color(hex: "#9bc1bc"),
                accent: Color(hex: "#5ca4a9"),
                timerRing: Color(hex: "#5ca4a9"),
                breakRing: Color(hex: "#9bc1bc"),
                ringTrack: Color(hex: "#e6ebe0")
            )

        case .navyGold:
            return ThemeColors(
                background: Color(hex: "#0d3b66"),
                surface: Color(hex: "#0d3b66"),
                text: Color(hex: "#faf0ca"),
                textSecondary: Color(hex: "#faf0ca"),
                accent: Color(hex: "#faf0ca"),
                timerRing: Color(hex: "#faf0ca"),
                breakRing: Color(hex: "#faf0ca"),
                ringTrack: Color(hex: "#0d3b66")
            )

        case .lightBlue:
            return ThemeColors(
                background: Color(hex: "#e7ecef"),
                surface: Color(hex: "#e7ecef"),
                text: Color(hex: "#274c77"),
                textSecondary: Color(hex: "#274c77"),
                accent: Color(hex: "#274c77"),
                timerRing: Color(hex: "#274c77"),
                breakRing: Color(hex: "#274c77"),
                ringTrack: Color(hex: "#e7ecef")
            )

        case .charcoalLight:
            return ThemeColors(
                background: Color(hex: "#223843"),
                surface: Color(hex: "#223843"),
                text: Color(hex: "#eff1f3"),
                textSecondary: Color(hex: "#eff1f3"),
                accent: Color(hex: "#eff1f3"),
                timerRing: Color(hex: "#eff1f3"),
                breakRing: Color(hex: "#eff1f3"),
                ringTrack: Color(hex: "#223843")
            )

        case .creamTeal:
            return ThemeColors(
                background: Color(hex: "#fffffa"),
                surface: Color(hex: "#fffffa"),
                text: Color(hex: "#0d5c63"),
                textSecondary: Color(hex: "#0d5c63"),
                accent: Color(hex: "#0d5c63"),
                timerRing: Color(hex: "#0d5c63"),
                breakRing: Color(hex: "#0d5c63"),
                ringTrack: Color(hex: "#fffffa")
            )

        case .redNavy:
            return ThemeColors(
                background: Color(hex: "#d7263d"),
                surface: Color(hex: "#d7263d"),
                text: Color(hex: "#02182b"),
                textSecondary: Color(hex: "#02182b"),
                accent: Color(hex: "#02182b"),
                timerRing: Color(hex: "#02182b"),
                breakRing: Color(hex: "#02182b"),
                ringTrack: Color(hex: "#d7263d")
            )
        }
    }
}
