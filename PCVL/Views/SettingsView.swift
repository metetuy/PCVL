import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    @ObservedObject var statsManager: StatisticsManager

    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false
    @State private var showingResetAlert = false
    @State private var showingThemeList = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Timer durations
                timerSection
                    .padding(.top, 14)

                // Theme & Display settings
                if showingThemeList {
                    compactThemeList
                } else {
                    themeMenuButton
                }
                displaySection

                // Window behavior
                behaviorSection

                // Data management
                resetButton

                Spacer()

                // Quit
                quitButton
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TIMER")

            VStack(spacing: 0) {
                durationRow(
                    label: "Work",
                    icon: "brain.head.profile",
                    minutes: viewModel.durationMinutes(for: .work),
                    onDecrement: {
                        viewModel.adjustDuration(.work, byMinutes: -TimerViewModel.AdjustableDuration.work.stepMinutes)
                    },
                    onIncrement: {
                        viewModel.adjustDuration(.work, byMinutes: TimerViewModel.AdjustableDuration.work.stepMinutes)
                    }
                )

                Divider().background(theme.colors.ringTrack)

                durationRow(
                    label: "Break",
                    icon: "cup.and.saucer",
                    minutes: viewModel.durationMinutes(for: .breakTime),
                    onDecrement: {
                        viewModel.adjustDuration(.breakTime, byMinutes: -TimerViewModel.AdjustableDuration.breakTime.stepMinutes)
                    },
                    onIncrement: {
                        viewModel.adjustDuration(.breakTime, byMinutes: TimerViewModel.AdjustableDuration.breakTime.stepMinutes)
                    }
                )
            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func durationRow(
        label: String,
        icon: String,
        minutes: Int,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 12))
                .foregroundColor(theme.colors.accent)
                .frame(width: 20)

            Text(label)
                .font(theme.currentFont.font(size: 12, weight: .medium))
                .foregroundColor(theme.colors.text)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(theme.currentFont.font(size: 10, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(theme.colors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIdle)

                Text("\(minutes) min")
                    .font(theme.currentFont.font(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.colors.text)
                    .frame(width: 50)

                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus")
                        .font(theme.currentFont.font(size: 10, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(theme.colors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIdle)
            }
            .opacity(viewModel.isIdle ? 1 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }



    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DISPLAY")

            VStack(spacing: 0) {
                // Font Picker
            VStack(spacing: 6) {
                    Text("Timer Font")
                        .font(theme.currentFont.font(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 2)

                    ForEach(AppFont.allCases) { appFont in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                theme.currentFont = appFont
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(appFont.rawValue)
                                    .font(appFont.font(size: 12, weight: .medium))
                                    .foregroundColor(
                                        theme.currentFont == appFont
                                            ? theme.colors.text
                                            : theme.colors.textSecondary
                                    )

                                Spacer()

                                if theme.currentFont == appFont {
                                    Image(systemName: "checkmark")
                                        .font(theme.currentFont.font(size: 10, weight: .bold))
                                        .foregroundColor(theme.colors.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .background(
                                theme.currentFont == appFont
                                    ? theme.colors.accent.opacity(0.08)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)

                if theme.currentFont != .system {
                    Divider().background(theme.colors.ringTrack)

                    // Font Weight (Inter only)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "textformat.size")
                                .font(theme.currentFont.font(size: 12))
                                .foregroundColor(theme.colors.accent)
                                .frame(width: 20)

                            Text("Font Weight")
                                .font(theme.currentFont.font(size: 12, weight: .medium))
                                .foregroundColor(theme.colors.text)

                            Spacer()

                            Text(theme.fontWeightLabel(theme.interFontWeightBoost))
                                .font(theme.currentFont.font(size: 11, weight: .medium))
                                .foregroundColor(theme.colors.accent)
                        }

                        Slider(value: Binding(
                            get: { Double(theme.interFontWeightBoost) },
                            set: { newValue in
                                theme.interFontWeightBoost = Int(newValue)
                            }
                        ), in: 0...3, step: 1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Theme Section
    
    private var themeMenuButton: some View {
        Button {
            showingThemeList = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(previewColor(for: theme.currentTheme))
                    .frame(width: 8, height: 8)

                Text(theme.currentTheme.rawValue)
                    .font(theme.currentFont.font(size: 12, weight: .medium))
                    .foregroundColor(theme.colors.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(theme.currentFont.font(size: 9, weight: .semibold))
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var compactThemeList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                showingThemeList = false
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(previewColor(for: theme.currentTheme))
                        .frame(width: 8, height: 8)

                    Text(theme.currentTheme.rawValue)
                        .font(theme.currentFont.font(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.text)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(theme.currentFont.font(size: 9, weight: .semibold))
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.colors.surface)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                ForEach(AppTheme.allCases) { appTheme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            theme.currentTheme = appTheme
                            showingThemeList = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(previewColor(for: appTheme))
                                .frame(width: 8, height: 8)

                            Text(appTheme.rawValue)
                                .font(theme.currentFont.font(size: 12))
                                .foregroundColor(
                                    theme.currentTheme == appTheme
                                        ? theme.colors.accent
                                        : theme.colors.textSecondary
                                )

                            Spacer()

                            if theme.currentTheme == appTheme {
                                Image(systemName: "checkmark")
                                    .font(theme.currentFont.font(size: 9, weight: .bold))
                                    .foregroundColor(theme.colors.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Display Section

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("WINDOW")

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "pin")
                        .font(theme.currentFont.font(size: 12))
                        .foregroundColor(theme.colors.accent)
                        .frame(width: 20)

                    Text("Always on Top")
                        .font(theme.currentFont.font(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.text)

                    Spacer()

                    Toggle("", isOn: $alwaysOnTop)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .onChange(of: alwaysOnTop) { _, newValue in
                            if let delegate = NSApp.delegate as? AppDelegate {
                                delegate.setAlwaysOnTop(newValue)
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().background(theme.colors.ringTrack)

                HStack {
                    Image(systemName: "menubar.rectangle")
                        .font(theme.currentFont.font(size: 12))
                        .foregroundColor(theme.colors.accent)
                        .frame(width: 20)

                    Text("Timer in Menu Bar")
                        .font(theme.currentFont.font(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.text)

                    Spacer()

                    Toggle("", isOn: $showTimerInMenuBar)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .onChange(of: showTimerInMenuBar) { _, _ in
                            viewModel.updateMenuBarIcon()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Data Management

    private var resetButton: some View {
        Button {
            showingResetAlert = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(theme.currentFont.font(size: 11))
                Text("Reset Statistics")
                    .font(theme.currentFont.font(size: 12, weight: .medium))
            }
            .foregroundColor(Color(nsColor: NSColor(red: 0.85, green: 0.4, blue: 0.2, alpha: 1)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .alert("Reset Statistics", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                statsManager.deleteAllSessions()
            }
        } message: {
            Text("Are you sure you want to delete all session records? This action cannot be undone.")
        }
    }

    // MARK: - Quit

    private var quitButton: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(theme.currentFont.font(size: 11))
                Text("Quit PCVL")
                    .font(theme.currentFont.font(size: 12, weight: .medium))
            }
            .foregroundColor(Color(nsColor: NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(theme.currentFont.font(size: 9, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(theme.colors.textSecondary)
    }

    private func previewColor(for appTheme: AppTheme) -> Color {
        switch appTheme {
        case .minimalist: return Color(nsColor: NSColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1))
        case .dark: return Color(nsColor: NSColor(red: 0.95, green: 0.6, blue: 0.25, alpha: 1))
        case .light: return Color(nsColor: NSColor(red: 0.3, green: 0.3, blue: 0.65, alpha: 1))
        case .ocean: return Color(nsColor: NSColor(red: 0.25, green: 0.7, blue: 0.85, alpha: 1))
        case .bloom: return Color(nsColor: NSColor(red: 0.95, green: 0.4, blue: 0.55, alpha: 1))
        
        case .roseDark: return Color(hex: "#dd2d4a")
        case .roseLight: return Color(hex: "#fb6f92")
        case .pinkSoft: return Color(hex: "#ff8fab")
        case .navyBlue: return Color(hex: "#415a77")
        case .slateBlue: return Color(hex: "#3e5c76")
        case .teaGreen: return Color(hex: "#1b4965")
        case .slateDark: return Color(hex: "#596d83")
        case .warmEarth: return Color(hex: "#5ca4a9")
        case .navyGold: return Color(hex: "#faf0ca")
        case .lightBlue: return Color(hex: "#274c77")
        case .charcoalLight: return Color(hex: "#eff1f3")
        case .creamTeal: return Color(hex: "#0d5c63")
        case .redNavy: return Color(hex: "#d7263d")
        }
    }
}
