import SwiftUI

// Value types behind user-created themes: an editable sRGB color, the palette a
// theme is made of, and how a theme (built-in or custom) is selected and listed.

// MARK: - RGB Color

/// sRGB color with components in 0...1. Persisted as a "#RRGGBB" hex string.
struct RGBColor: Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// Accepts "#RRGGBB", "RRGGBB" and the short "#RGB" form; nil for anything else.
    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Resolves any SwiftUI color (system colors in the current appearance) to sRGB.
    init(_ color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: resolved.redComponent, green: resolved.greenComponent, blue: resolved.blueComponent)
    }

    /// Hue wraps around (1 == 0); saturation and brightness are 0...1.
    init(hue: Double, saturation: Double, brightness: Double) {
        let sector = (hue - hue.rounded(.down)) * 6
        let fraction = sector - sector.rounded(.down)
        let v = brightness
        let p = v * (1 - saturation)
        let q = v * (1 - saturation * fraction)
        let t = v * (1 - saturation * (1 - fraction))
        switch Int(sector) % 6 {
        case 0: self.init(red: v, green: t, blue: p)
        case 1: self.init(red: q, green: v, blue: p)
        case 2: self.init(red: p, green: v, blue: t)
        case 3: self.init(red: p, green: q, blue: v)
        case 4: self.init(red: t, green: p, blue: v)
        default: self.init(red: v, green: p, blue: q)
        }
    }

    var hex: String {
        String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(red, green, blue)
        let delta = maxValue - min(red, green, blue)
        var hue = 0.0
        if delta > 0 {
            if maxValue == red {
                hue = (green - blue) / delta
            } else if maxValue == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxValue == 0 ? 0 : delta / maxValue, maxValue)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    private func byte(_ component: Double) -> Int { Int((component * 255).rounded()) }
}

extension RGBColor: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        guard let color = RGBColor(hex: hex) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid hex color \(hex)")
        }
        self = color
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

// MARK: - Palette

/// The colors a user picks for a theme. `timerRing` always follows `accent`, as in
/// every built-in theme.
enum ThemeColorRole: String, CaseIterable, Identifiable {
    case background, surface, text, textSecondary, accent, breakRing, ringTrack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .background: return "Background"
        case .surface: return "Surface"
        case .text: return "Text"
        case .textSecondary: return "Secondary text"
        case .accent: return "Accent"
        case .breakRing: return "Break"
        case .ringTrack: return "Track"
        }
    }

    var detail: String {
        switch self {
        case .background: return "Panel and window background"
        case .surface: return "Cards, buttons and toggles"
        case .text: return "Time and titles"
        case .textSecondary: return "Labels and icons"
        case .accent: return "Focus progress and the main button"
        case .breakRing: return "Break progress"
        case .ringTrack: return "Progress track and dividers"
        }
    }

    fileprivate var keyPath: WritableKeyPath<ThemePalette, RGBColor> {
        switch self {
        case .background: return \.background
        case .surface: return \.surface
        case .text: return \.text
        case .textSecondary: return \.textSecondary
        case .accent: return \.accent
        case .breakRing: return \.breakRing
        case .ringTrack: return \.ringTrack
        }
    }
}

struct ThemePalette: Codable, Hashable {
    var background: RGBColor
    var surface: RGBColor
    var text: RGBColor
    var textSecondary: RGBColor
    var accent: RGBColor
    var breakRing: RGBColor
    var ringTrack: RGBColor

    /// Snapshot of an existing theme's colors, e.g. to start a new theme from it.
    init(_ colors: ThemeColors) {
        background = RGBColor(colors.background)
        surface = RGBColor(colors.surface)
        text = RGBColor(colors.text)
        textSecondary = RGBColor(colors.textSecondary)
        accent = RGBColor(colors.accent)
        breakRing = RGBColor(colors.breakRing)
        ringTrack = RGBColor(colors.ringTrack)
    }

    subscript(role: ThemeColorRole) -> RGBColor {
        get { self[keyPath: role.keyPath] }
        set { self[keyPath: role.keyPath] = newValue }
    }

    var colors: ThemeColors {
        ThemeColors(
            background: background.color,
            surface: surface.color,
            text: text.color,
            textSecondary: textSecondary.color,
            accent: accent.color,
            timerRing: accent.color,
            breakRing: breakRing.color,
            ringTrack: ringTrack.color
        )
    }

    /// The palette rules every theme follows (see `ThemeManager.makeColors`).
    var problems: [String] {
        var problems: [String] = []
        if ringTrack.hex == background.hex || ringTrack.hex == surface.hex {
            problems.append("Track must differ from background and surface.")
        }
        if accent.hex == textSecondary.hex {
            problems.append("Accent must differ from secondary text.")
        }
        return problems
    }
}

// MARK: - Custom Theme

struct CustomTheme: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var palette: ThemePalette
}

// MARK: - Selection

/// The selected theme: one of the built-ins or a custom theme.
enum ThemeSelection: Hashable {
    case builtIn(AppTheme)
    case custom(UUID)

    private static let customPrefix = "custom:"

    /// A built-in theme's raw value (as stored before custom themes) or "custom:<uuid>".
    init?(storageValue: String) {
        if storageValue.hasPrefix(Self.customPrefix) {
            guard let id = UUID(uuidString: String(storageValue.dropFirst(Self.customPrefix.count))) else { return nil }
            self = .custom(id)
        } else {
            guard let theme = AppTheme(rawValue: storageValue) else { return nil }
            self = .builtIn(theme)
        }
    }

    var storageValue: String {
        switch self {
        case .builtIn(let theme): return theme.rawValue
        case .custom(let id): return Self.customPrefix + id.uuidString
        }
    }

    var customID: UUID? {
        if case .custom(let id) = self { return id }
        return nil
    }
}

/// A row in any theme list (settings grid, flyout, context menu).
struct ThemeOption: Identifiable {
    let selection: ThemeSelection
    let name: String
    let colors: ThemeColors

    var id: ThemeSelection { selection }
}
