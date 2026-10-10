import SwiftUI

// MARK: - Expand Handle

/// Bottom-edge affordance in the panel that opens the full window. A small chevron
/// fades in while the panel is hovered and grows into "Expand for details" when
/// the pointer reaches it.
struct ExpandHandle: View {
    @ObservedObject var theme: ThemeManager
    let isPanelHovered: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(theme.currentFont.font(size: 8, weight: .bold))
                if isHovering {
                    Text("Expand for details")
                        .font(theme.currentFont.font(size: 9, weight: .medium))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .foregroundColor(isHovering ? theme.colors.accent : theme.colors.textSecondary)
            .padding(.horizontal, isHovering ? 10 : 8)
            .padding(.vertical, 3)
            .background(theme.colors.surface.opacity(isHovering ? 1 : 0.6))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(theme.colors.text.opacity(isHovering ? 0.08 : 0), lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .opacity(isPanelHovered || isHovering ? 1 : 0)
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.18), value: isPanelHovered)
        .onHover { isHovering = $0 }
        .pointerStyle(.link)
        .help("Open the PCVL window")
    }
}
