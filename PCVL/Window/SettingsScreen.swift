import SwiftUI

// MARK: - Settings Screen

/// Window-sized settings: timer durations, appearance with live theme previews,
/// menu bar behavior and data management.
struct SettingsScreen: View {
    @ObservedObject var timerViewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    let statsManager: StatisticsManager

    @AppStorage("alwaysOnTop") private var alwaysOnTop = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = false
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(theme.currentFont.font(size: 20, weight: .semibold))
                    .foregroundColor(theme.colors.text)

                timerSection
                themeSection
                fontSection
                menuBarSection
                dataSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .alert("Reset Statistics", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                statsManager.deleteAllSessions()
            }
        } message: {
            Text("Are you sure you want to delete all session records? This action cannot be undone.")
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        settingsGroup("Timer", footnote: timerViewModel.isIdle ? nil : "Durations can be changed while the timer is idle.") {
            durationRow(.work, title: "Focus duration", subtitle: "5–480 minutes")
            divider
            durationRow(.breakTime, title: "Break duration", subtitle: "1–30 minutes")
        }
    }

    private func durationRow(_ duration: TimerViewModel.AdjustableDuration, title: String, subtitle: String) -> some View {
        row(title: title, subtitle: subtitle) {
            HStack(spacing: 12) {
                stepButton(icon: "minus") {
                    timerViewModel.adjustDuration(duration, byMinutes: -duration.stepMinutes)
                }
                Text("\(timerViewModel.durationMinutes(for: duration)) min")
                    .font(theme.currentFont.font(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.colors.text)
                    .frame(minWidth: 64)
                stepButton(icon: "plus") {
                    timerViewModel.adjustDuration(duration, byMinutes: duration.stepMinutes)
                }
            }
            .disabled(!timerViewModel.isIdle)
            .opacity(timerViewModel.isIdle ? 1 : 0.4)
        }
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 10, weight: .bold))
                .foregroundColor(theme.colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(theme.colors.background)
                .clipShape(Circle())
        }
        .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
        .hoverEffect()
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Theme", theme: theme, scale: 1.2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(AppTheme.allCases) { appTheme in
                    ThemeTile(appTheme: appTheme, theme: theme) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            theme.currentTheme = appTheme
                        }
                    }
                }
            }
        }
    }

    // MARK: - Font

    private var fontSection: some View {
        settingsGroup("Font") {
            row(title: "Typeface", subtitle: "Used across the app and the timer") {
                CapsuleSegmentedControl(
                    options: AppFont.allCases,
                    selection: Binding(get: { theme.currentFont }, set: { theme.currentFont = $0 }),
                    title: \.rawValue,
                    theme: theme,
                    scale: 1.3
                )
            }

            if theme.currentFont != .system {
                divider
                row(title: "Weight", subtitle: theme.fontWeightLabel(theme.interFontWeightBoost)) {
                    Slider(
                        value: Binding(
                            get: { Double(theme.interFontWeightBoost) },
                            set: { theme.interFontWeightBoost = Int($0) }
                        ),
                        in: 0...3,
                        step: 1
                    )
                    .frame(width: 180)
                }
            }
        }
    }

    // MARK: - Menu Bar

    private var menuBarSection: some View {
        settingsGroup("Menu bar panel") {
            row(title: "Always on top", subtitle: "Keep the panel open above other windows") {
                Toggle("", isOn: $alwaysOnTop)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            divider
            row(title: "Timer in menu bar", subtitle: "Show the remaining time next to the icon") {
                Toggle("", isOn: $showTimerInMenuBar)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        settingsGroup("Data") {
            row(title: "Export sessions", subtitle: "Save every recorded session as JSON") {
                actionButton(title: "Export…", icon: "square.and.arrow.up", color: theme.colors.text) {
                    statsManager.exportSessionsToJSON()
                }
            }
            divider
            row(title: "Reset statistics", subtitle: "Delete all session records") {
                actionButton(title: "Reset…", icon: "trash", color: Color(nsColor: NSColor(red: 0.85, green: 0.4, blue: 0.2, alpha: 1))) {
                    showingResetAlert = true
                }
            }
            divider
            row(title: "Quit PCVL", subtitle: nil) {
                actionButton(title: "Quit", icon: "power", color: Color(nsColor: NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1))) {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(theme.currentFont.font(size: 11))
                Text(title)
                    .font(theme.currentFont.font(size: 12, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    // MARK: - Layout Helpers

    private func settingsGroup<Content: View>(
        _ title: String,
        footnote: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, theme: theme, scale: 1.2)
            VStack(spacing: 0) {
                content()
            }
            .cardBackground(theme, radius: 10)
            if let footnote {
                Text(footnote)
                    .font(theme.currentFont.font(size: 11))
                    .foregroundColor(theme.colors.textSecondary)
            }
        }
    }

    private func row<Trailing: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.currentFont.font(size: 13, weight: .medium))
                    .foregroundColor(theme.colors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(theme.currentFont.font(size: 11))
                        .foregroundColor(theme.colors.textSecondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Divider().background(theme.colors.ringTrack)
    }
}

// MARK: - Theme Tile

/// Miniature preview of a theme: its background, a text bar and an accent pill.
private struct ThemeTile: View {
    let appTheme: AppTheme
    @ObservedObject var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        let colors = ThemeManager.colors(for: appTheme)
        let isSelected = theme.currentTheme == appTheme

        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.text.opacity(0.85))
                        .frame(width: 44, height: 5)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors.textSecondary.opacity(0.6))
                        .frame(width: 28, height: 4)
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Capsule().fill(colors.accent).frame(width: 30, height: 9)
                        Capsule().fill(colors.breakRing).frame(width: 12, height: 9)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                .background(colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.08), lineWidth: 0.5))

                HStack {
                    Text(appTheme.rawValue)
                        .font(theme.currentFont.font(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? theme.colors.text : theme.colors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(theme.currentFont.font(size: 10, weight: .bold))
                            .foregroundColor(theme.colors.accent)
                    }
                }
            }
            .padding(8)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.colors.accent : theme.colors.text.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}
