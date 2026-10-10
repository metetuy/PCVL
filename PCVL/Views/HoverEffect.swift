import SwiftUI

// MARK: - Hover Effect

/// Adds a pointing-hand cursor and a subtle opacity dim while the view is hovered.
struct HoverOpacityModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .opacity(isHovering ? 0.75 : 1)
            .onHover { isHovering = $0 }
            // Unlike NSCursor push/pop, this can't leave the cursor stuck when the
            // view disappears while hovered.
            .pointerStyle(.link)
    }
}

extension View {
    /// Dims the view and shows a pointing-hand cursor on hover.
    func hoverEffect() -> some View {
        modifier(HoverOpacityModifier())
    }
}
