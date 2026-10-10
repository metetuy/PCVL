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

    /// Blends this color toward white, for deriving a lighter variant used in panel gradients.
    func lightened(by amount: CGFloat) -> Color {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        return Color(nsColor: nsColor.blended(withFraction: amount, of: .white) ?? nsColor)
    }

    /// Blends this color toward black, for deriving a darker variant used in panel gradients.
    func darkened(by amount: CGFloat) -> Color {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        return Color(nsColor: nsColor.blended(withFraction: amount, of: .black) ?? nsColor)
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

    /// Swatch color used to represent this theme in pickers (e.g. the theme flyout).
    var previewColor: Color { ThemeManager.colors(for: self).accent }
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

final class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: Keys.theme) }
    }
    @Published var currentFont: AppFont {
        didSet { UserDefaults.standard.set(currentFont.rawValue, forKey: Keys.font) }
    }
    /// Extra weight steps (0–3) applied to Inter in the timer display.
    @Published var interFontWeightBoost: Int {
        didSet { UserDefaults.standard.set(interFontWeightBoost, forKey: Keys.weightBoost) }
    }

    private enum Keys {
        static let theme = "selectedTheme"
        static let font = "selectedFont"
        static let weightBoost = "interFontWeightBoost"
    }

    init() {
        let defaults = UserDefaults.standard
        currentTheme = defaults.string(forKey: Keys.theme).flatMap(AppTheme.init(rawValue:)) ?? .minimalist
        currentFont = defaults.string(forKey: Keys.font).flatMap(AppFont.init(rawValue:)) ?? .system
        interFontWeightBoost = (defaults.object(forKey: Keys.weightBoost) as? Int) ?? 1
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
        Self.colors(for: currentTheme)
    }

    /// Palette of any theme, e.g. for previews in the theme picker. Built once per
    /// theme: views read colors many times per render.
    static func colors(for theme: AppTheme) -> ThemeColors {
        palettes[theme] ?? makeColors(for: .minimalist)
    }

    private static let palettes: [AppTheme: ThemeColors] = Dictionary(
        uniqueKeysWithValues: AppTheme.allCases.map { ($0, makeColors(for: $0)) }
    )

    /// `ringTrack` must differ from both `background` and `surface` (it draws the
    /// progress track and dividers), and `accent` from `textSecondary` (selected vs
    /// unselected controls).
    private static func makeColors(for theme: AppTheme) -> ThemeColors {
        switch theme {
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
                ringTrack: Color(hex: "#2a3a52")
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
                ringTrack: Color(hex: "#2b3d57")
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
                ringTrack: Color(hex: "#25384a")
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
                surface: Color(hex: "#114d86"),
                text: Color(hex: "#faf0ca"),
                textSecondary: Color(hex: "#a9bccf"),
                accent: Color(hex: "#f4d35e"),
                timerRing: Color(hex: "#f4d35e"),
                breakRing: Color(hex: "#ee964b"),
                ringTrack: Color(hex: "#2a5d8f")
            )

        case .lightBlue:
            return ThemeColors(
                background: Color(hex: "#e7ecef"),
                surface: Color(hex: "#c9e0ee"),
                text: Color(hex: "#274c77"),
                textSecondary: Color(hex: "#6b7c8c"),
                accent: Color(hex: "#274c77"),
                timerRing: Color(hex: "#274c77"),
                breakRing: Color(hex: "#6096ba"),
                ringTrack: Color(hex: "#b3c6d4")
            )

        case .charcoalLight:
            return ThemeColors(
                background: Color(hex: "#223843"),
                surface: Color(hex: "#2e4c5b"),
                text: Color(hex: "#eff1f3"),
                textSecondary: Color(hex: "#9fb1ba"),
                accent: Color(hex: "#d77a61"),
                timerRing: Color(hex: "#d77a61"),
                breakRing: Color(hex: "#d8b4a0"),
                ringTrack: Color(hex: "#3b5a69")
            )

        case .creamTeal:
            return ThemeColors(
                background: Color(hex: "#fffffa"),
                surface: Color(hex: "#f0f0eb"),
                text: Color(hex: "#0d5c63"),
                textSecondary: Color(hex: "#6b8f91"),
                accent: Color(hex: "#0d5c63"),
                timerRing: Color(hex: "#0d5c63"),
                breakRing: Color(hex: "#44a1a0"),
                ringTrack: Color(hex: "#dce3df")
            )

        case .redNavy:
            return ThemeColors(
                background: Color(hex: "#d7263d"),
                surface: Color(hex: "#bd2136"),
                text: Color(hex: "#02182b"),
                textSecondary: Color(hex: "#5e1020"),
                accent: Color(hex: "#fbeee0"),
                timerRing: Color(hex: "#fbeee0"),
                breakRing: Color(hex: "#02182b"),
                ringTrack: Color(hex: "#a81c30")
            )
        }
    }
}
