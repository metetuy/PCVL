import SwiftUI

// Theme editor building blocks, independent of where the editor is shown (the
// window today, possibly the panel later). Chrome uses the app's current theme;
// only `ThemePreview` draws the palette being edited.

// MARK: - Theme Preview

/// The menu bar panel's timer tab drawn with any palette, at the panel's real size.
struct ThemePreview: View {
    let colors: ThemeColors
    /// Fonts only: the preview follows the chosen typeface.
    @ObservedObject var theme: ThemeManager
    var isBreak = false

    static let size = CGSize(width: 300, height: 190)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["timer", "checklist", "chart.bar", "gear"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(theme.currentFont.font(size: 12))
                        .foregroundColor(icon == "timer" ? colors.accent : colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 32)
            .padding(.horizontal, 8)
            Rectangle().fill(colors.ringTrack).frame(height: 1)

            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    modeSegment("Timer", isSelected: true)
                    modeSegment("Stopwatch", isSelected: false)
                }
                .padding(2)
                .background(colors.surface)
                .clipShape(Capsule())
                Spacer()
                Text(isBreak ? "BREAK" : "FOCUS")
                    .font(theme.currentFont.font(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(colors.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
            HStack(spacing: 12) {
                circleButton("arrow.counterclockwise")
                VStack(spacing: 6) {
                    Text(isBreak ? "03:12" : "18:42")
                        .font(theme.timerFont(size: 36, weight: .thin))
                        .foregroundColor(colors.text)
                    progressLine
                    Text("Resume")
                        .font(theme.currentFont.font(size: 11.5, weight: .semibold))
                        .foregroundColor(colors.background)
                        .frame(minWidth: 78, minHeight: 25)
                        .padding(.horizontal, 15)
                        .background(colors.accent)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                circleButton("forward.end")
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(ThemedBackground.gradient(colors.background))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.text.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isBreak)
    }

    private func modeSegment(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(theme.currentFont.font(size: 9, weight: .medium))
            .foregroundColor(isSelected ? colors.accent : colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? colors.accent.opacity(0.12) : Color.clear)
            .clipShape(Capsule())
    }

    private func circleButton(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(theme.currentFont.font(size: 11, weight: .medium))
            .foregroundColor(colors.textSecondary)
            .frame(width: 26, height: 26)
            .background(colors.surface)
            .clipShape(Circle())
    }

    private var progressLine: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(colors.ringTrack)
                Capsule()
                    .fill(isBreak ? colors.breakRing : colors.timerRing)
                    .frame(width: geo.size.width * (isBreak ? 0.36 : 0.62))
            }
        }
        .frame(height: 3)
    }
}

// MARK: - Role List

/// The palette's colors, one row each; clicking a row picks the color to edit.
struct ThemeRoleList: View {
    let palette: ThemePalette
    @Binding var selection: ThemeColorRole
    @ObservedObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 2) {
            ForEach(ThemeColorRole.allCases) { role in
                let isSelected = role == selection
                Button {
                    selection = role
                } label: {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(palette[role].color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(theme.colors.text.opacity(0.15), lineWidth: 0.5))
                        Text(role.title)
                            .font(theme.currentFont.font(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? theme.colors.text : theme.colors.textSecondary)
                        Spacer()
                        Text(palette[role].hex)
                            .font(theme.currentFont.font(size: 11, design: .monospaced))
                            .foregroundColor(theme.colors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(isSelected ? theme.colors.accent.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect()
                .help(role.detail)
            }
        }
    }
}

// MARK: - Color Picker

/// Spectrum (saturation × brightness of one hue), hue bar, hex field and typical
/// swatches, all editing one color.
struct ThemeColorPicker: View {
    @Binding var color: RGBColor
    let swatches: [RGBColor]
    @ObservedObject var theme: ThemeManager
    var spectrumHeight: CGFloat = 140

    /// Kept apart from `color`: grays have no hue of their own, and the spectrum
    /// must not jump back to red when one is picked.
    @State private var hue: Double = 0

    private static let hueStops = (0...6).map { RGBColor(hue: Double($0) / 6, saturation: 1, brightness: 1).color }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            spectrum
            hueBar
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.color)
                    .frame(width: 28, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.colors.text.opacity(0.15), lineWidth: 0.5))
                HexColorField(color: $color, theme: theme)
            }
            swatchGrid
        }
        .onAppear(perform: syncHue)
        .onChange(of: color) { _, _ in syncHue() }
    }

    private func syncHue() {
        let hsb = color.hsb
        if hsb.saturation > 0, hsb.brightness > 0 {
            hue = hsb.hue
        }
    }

    private var spectrum: some View {
        let hsb = color.hsb
        return GeometryReader { geo in
            ZStack {
                ZStack {
                    RGBColor(hue: hue, saturation: 1, brightness: 1).color
                    LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                marker(fill: color.color)
                    .position(x: hsb.saturation * geo.size.width, y: (1 - hsb.brightness) * geo.size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                color = RGBColor(
                    hue: hue,
                    saturation: fraction(value.location.x, of: geo.size.width),
                    brightness: 1 - fraction(value.location.y, of: geo.size.height)
                )
            })
        }
        .frame(height: spectrumHeight)
    }

    private var hueBar: some View {
        GeometryReader { geo in
            ZStack {
                Capsule().fill(LinearGradient(colors: Self.hueStops, startPoint: .leading, endPoint: .trailing))
                marker(fill: RGBColor(hue: hue, saturation: 1, brightness: 1).color)
                    .position(x: hue * geo.size.width, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                // Short of 1, which is red again and would snap the marker to the start.
                hue = min(fraction(value.location.x, of: geo.size.width), 0.9999)
                let hsb = color.hsb
                color = RGBColor(hue: hue, saturation: hsb.saturation, brightness: hsb.brightness)
            })
        }
        .frame(height: 12)
    }

    private var swatchGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(swatches, id: \.self) { swatch in
                let isSelected = swatch.hex == color.hex
                Button {
                    color = swatch
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(swatch.color)
                        .frame(height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? theme.colors.accent : theme.colors.text.opacity(0.15), lineWidth: isSelected ? 2 : 0.5)
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect()
                .help(swatch.hex)
            }
        }
    }

    private func marker(fill: Color) -> some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.35), radius: 1.5)
            .frame(width: 14, height: 14)
            .allowsHitTesting(false)
    }

    private func fraction(_ value: CGFloat, of length: CGFloat) -> Double {
        length > 0 ? min(max(value / length, 0), 1) : 0
    }
}

// MARK: - Hex Field

/// Hex input: six digits apply as they are typed, the short "#RGB" form on Return;
/// anything invalid reverts when editing ends.
private struct HexColorField: View {
    @Binding var color: RGBColor
    @ObservedObject var theme: ThemeManager

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("#RRGGBB", text: $text)
            .textFieldStyle(.plain)
            .font(theme.currentFont.font(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(RGBColor(hex: text) == nil ? theme.colors.textSecondary : theme.colors.text)
            .focused($isFocused)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(width: 104)
            .cardBackground(theme, radius: 6)
            .onAppear { text = color.hex }
            .onChange(of: color) { _, newColor in
                // Leave the text alone while it already describes this color (mid-typing).
                if RGBColor(hex: text)?.hex != newColor.hex {
                    text = newColor.hex
                }
            }
            .onChange(of: text) { _, newText in
                if newText.filter(\.isHexDigit).count == 6, let parsed = RGBColor(hex: newText) {
                    color = parsed
                }
            }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        if let parsed = RGBColor(hex: text) {
            color = parsed
        }
        text = color.hex
    }
}
