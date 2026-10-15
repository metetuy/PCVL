import SwiftUI

// MARK: - Themed Background

/// Static per-theme radial gradient used behind the panel and the window, so both
/// render the same vignette look regardless of what's behind them.
struct ThemedBackground: View {
    @ObservedObject var theme: ThemeManager
    /// Gradient radius; small for the panel, larger for the window.
    var radius: CGFloat = 220

    var body: some View {
        Self.gradient(theme.colors.background, radius: radius)
    }

    /// The same vignette for any background color, e.g. a theme preview.
    static func gradient(_ background: Color, radius: CGFloat = 220) -> RadialGradient {
        RadialGradient(
            colors: [
                background.lightened(by: 0.06),
                background.darkened(by: 0.18)
            ],
            center: UnitPoint(x: 0.5, y: 0.35),
            startRadius: 4,
            endRadius: radius
        )
    }
}
