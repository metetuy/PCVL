import SwiftUI

// MARK: - Theme Button Frame Tracking

/// Reports the theme menu button's frame (in the panel's coordinate space) so
/// AppDelegate can position the flyout panel next to it.
struct ThemeButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Theme Flyout

/// Content hosted in the standalone flyout panel that pops out beside the
/// main panel — mirrors the app's card styling rather than a system menu.
struct ThemeFlyoutView: View {
    static let rowHeight: CGFloat = 28
    static let width: CGFloat = 180
    static let verticalPadding: CGFloat = 4
    static let visibleRows: Int = 6

    /// The scrolling theme list plus the fixed "Create Theme…" row below it.
    static var height: CGFloat {
        CGFloat(visibleRows + 1) * rowHeight + verticalPadding * 2 + 1
    }

    @ObservedObject var theme: ThemeManager
    var onSelect: (ThemeSelection) -> Void
    /// Opens the window's theme editor.
    var onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            themeList
            Rectangle().fill(theme.colors.ringTrack).frame(height: 1)
            createRow
        }
        .frame(width: Self.width, height: Self.height)
        .background(
            RadialGradient(
                colors: [
                    theme.colors.surface.lightened(by: 0.06),
                    theme.colors.surface.darkened(by: 0.18)
                ],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 4,
                endRadius: 160
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var createRow: some View {
        Button(action: onCreate) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(theme.currentFont.font(size: 9, weight: .bold))
                    .foregroundColor(theme.colors.accent)
                    .frame(width: 8)
                Text("Create Theme…")
                    .font(theme.currentFont.font(size: 12))
                    .foregroundColor(theme.colors.text)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private var themeList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(theme.themeOptions) { option in
                    Button {
                        onSelect(option.selection)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(option.colors.accent)
                                .frame(width: 8, height: 8)

                            Text(option.name)
                                .font(theme.currentFont.font(size: 12))
                                .foregroundColor(
                                    theme.currentTheme == option.selection
                                        ? theme.colors.accent
                                        : theme.colors.textSecondary
                                )

                            Spacer()

                            if theme.currentTheme == option.selection {
                                Image(systemName: "checkmark")
                                    .font(theme.currentFont.font(size: 9, weight: .bold))
                                    .foregroundColor(theme.colors.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: Self.rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                }
            }
            .padding(.vertical, Self.verticalPadding)
        }
    }
}
