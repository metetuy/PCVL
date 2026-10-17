import SwiftUI

// Theme editor building blocks, independent of where the editor is shown (the
// window today, possibly the panel later). Chrome uses the app's current theme;
// only `ThemePreview` draws the palette being edited.

// MARK: - Theme Preview

/// Two screens drawn with any palette, at the panel's real size, side by side in a
/// pager: the timer tab and a sample of the analytics. A horizontal trackpad scroll
/// (or a dot) switches between them.
struct ThemePreview: View {
    let colors: ThemeColors
    /// Fonts only: the preview follows the chosen typeface.
    @ObservedObject var theme: ThemeManager
    var isBreak = false

    static let size = CGSize(width: 300, height: 190)

    private enum Page: Int, CaseIterable {
        case timer, analytics

        var title: String {
            switch self {
            case .timer: return "Timer"
            case .analytics: return "Analytics"
            }
        }
    }

    @State private var page: Page? = .timer

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    TimerPreviewPage(colors: colors, theme: theme, isBreak: isBreak)
                        .id(Page.timer)
                    AnalyticsPreviewPage(colors: colors, theme: theme)
                        .id(Page.analytics)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(RoundedRectangle(cornerRadius: 12).fill(colors.background).shadow(color: .black.opacity(0.18), radius: 10, y: 4))

            HStack(spacing: 14) {
                ForEach(Page.allCases, id: \.self) { item in
                    let isSelected = (page ?? .timer) == item
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { page = item }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isSelected ? theme.colors.accent : theme.colors.textSecondary.opacity(0.35))
                                .frame(width: 6, height: 6)
                            Text(item.title)
                                .font(theme.currentFont.font(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? theme.colors.text : theme.colors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: Self.size.width)
        }
    }
}

/// The menu bar panel's timer tab.
private struct TimerPreviewPage: View {
    let colors: ThemeColors
    @ObservedObject var theme: ThemeManager
    let isBreak: Bool

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
                        .foregroundColor(colors.focusText)
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
        .frame(width: ThemePreview.size.width, height: ThemePreview.size.height)
        .background(ThemedBackground.gradient(colors.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.text.opacity(0.08), lineWidth: 0.5))
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

/// A made-up week of statistics: range picker, headline numbers and a bar chart.
private struct AnalyticsPreviewPage: View {
    let colors: ThemeColors
    @ObservedObject var theme: ThemeManager

    /// Focus and break hours per weekday, Monday first.
    private let days: [(label: String, focus: Double, rest: Double)] = [
        ("M", 0.55, 0.12), ("T", 0.8, 0.2), ("W", 0.4, 0.1), ("T", 0.95, 0.25),
        ("F", 0.65, 0.15), ("S", 0.25, 0.05), ("S", 0.5, 0.1),
    ]
    private let ranges = ["Day", "Week", "Month"]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Analytics")
                    .font(theme.currentFont.font(size: 13, weight: .semibold))
                    .foregroundColor(colors.text)
                Spacer()
                HStack(spacing: 0) {
                    ForEach(ranges, id: \.self) { range in
                        Text(range)
                            .font(theme.currentFont.font(size: 8.5, weight: .medium))
                            .foregroundColor(range == "Week" ? colors.accent : colors.textSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(range == "Week" ? colors.accent.opacity(0.12) : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .padding(2)
                .background(colors.surface)
                .clipShape(Capsule())
            }

            HStack(spacing: 6) {
                statCard("Focus", value: "12h 40m", valueColor: colors.accent)
                statCard("Sessions", value: "28")
                statCard("Streak", value: "6 days")
            }

            chart
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: ThemePreview.size.width, height: ThemePreview.size.height)
        .background(ThemedBackground.gradient(colors.background))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.text.opacity(0.08), lineWidth: 0.5))
    }

    private func statCard(_ title: String, value: String, valueColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(theme.currentFont.font(size: 8, weight: .medium))
                .foregroundColor(colors.textSecondary)
            Text(value)
                .font(theme.currentFont.font(size: 12, weight: .semibold))
                .foregroundColor(valueColor ?? colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(colors.text.opacity(0.06), lineWidth: 0.5))
    }

    private var chart: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(colors.ringTrack).frame(height: 0.5)
                        Spacer(minLength: 0)
                    }
                }
                HStack(alignment: .bottom, spacing: 9) {
                    ForEach(days.indices, id: \.self) { index in
                        VStack(spacing: 1.5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors.breakRing)
                                .frame(height: days[index].rest * 52)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors.accent)
                                .frame(height: days[index].focus * 52)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(spacing: 9) {
                ForEach(days.indices, id: \.self) { index in
                    Text(days[index].label)
                        .font(theme.currentFont.font(size: 8))
                        .foregroundColor(colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
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

    /// The picker's own position, the source of truth while dragging. Re-deriving it
    /// from the RGB color on every change would wobble (and grays have no hue), so it
    /// is only re-read when the color changes from elsewhere (hex, swatch, other role).
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    /// The last color this picker produced, to tell its own changes from outside ones.
    @State private var emitted: RGBColor?

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
        .onAppear(perform: syncFromColor)
        .onChange(of: color) { _, newColor in
            if newColor != emitted { syncFromColor() }
        }
    }

    private func syncFromColor() {
        let hsb = color.hsb
        saturation = hsb.saturation
        brightness = hsb.brightness
        if hsb.saturation > 0, hsb.brightness > 0 {
            hue = hsb.hue
        }
    }

    private func emit() {
        let newColor = RGBColor(hue: hue, saturation: saturation, brightness: brightness)
        emitted = newColor
        color = newColor
    }

    private var spectrum: some View {
        GeometryReader { geo in
            ZStack {
                ZStack {
                    RGBColor(hue: hue, saturation: 1, brightness: 1).color
                    LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                marker(fill: color.color)
                    .position(x: saturation * geo.size.width, y: (1 - brightness) * geo.size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                saturation = fraction(value.location.x, of: geo.size.width)
                brightness = 1 - fraction(value.location.y, of: geo.size.height)
                emit()
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
                emit()
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
/// anything invalid reverts when editing ends. Only writes the color when the text
/// names a different one: echoing the displayed hex back would round every drag of
/// the spectrum to 8 bits per channel.
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
                if newText.filter(\.isHexDigit).count == 6, let parsed = RGBColor(hex: newText), parsed.hex != color.hex {
                    color = parsed
                }
            }
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
    }

    private func commit() {
        if let parsed = RGBColor(hex: text), parsed.hex != color.hex {
            color = parsed
        }
        text = color.hex
    }
}
