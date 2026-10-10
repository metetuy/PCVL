import SwiftUI

// MARK: - Themed Background

/// Static per-theme radial gradient used behind the panel and the window, so both
/// render the same vignette look regardless of what's behind them.
struct ThemedBackground: View {
    @ObservedObject var theme: ThemeManager
    /// Gradient radius; small for the panel, larger for the window.
    var radius: CGFloat = 220

    var body: some View {
        RadialGradient(
            colors: [
                theme.colors.background.lightened(by: 0.06),
                theme.colors.background.darkened(by: 0.18)
            ],
            center: UnitPoint(x: 0.5, y: 0.35),
            startRadius: 4,
            endRadius: radius
        )
    }
}
