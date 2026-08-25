import SwiftUI

// MARK: - Spring Button Style

/// Asymmetric press animation: pressing down is a fast ease-out with no
/// overshoot, releasing is a spring that overshoots slightly. A spring in
/// both directions reads as mushy, so the two directions use different curves.
struct SpringButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    let kind: Kind
    let theme: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.30, dampingFraction: 0.60),
                value: configuration.isPressed
            )
    }

    private var pressedScale: CGFloat {
        switch kind {
        case .primary:   return 0.90
        case .secondary: return 0.86
        }
    }
}
