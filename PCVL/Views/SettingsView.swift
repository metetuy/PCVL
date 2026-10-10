import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    @ObservedObject var statsManager: StatisticsManager
    var onShowThemePicker: (CGRect) -> Void

    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar: Bool = false
    @State private var showingResetAlert = false
    @State private var themeButtonFrame: CGRect = .zero

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Timer durations
                timerSection
                    .padding(.top, 10)

                // Theme & Display settings
                themeMenuButton
                displaySection

                // Window behavior
                behaviorSection

                // Data management
                resetButton

                Spacer()

                // Quit
                quitButton
                    // Leaves room for the panel's expand handle.
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 14)
        }
        .onPreferenceChange(ThemeButtonFramePreferenceKey.self) { themeButtonFrame = $0 }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TIMER")

            VStack(spacing: 0) {
                durationRow(
                    label: "Work",
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
        }
    }

    private func durationRow(
        label: String,
        minutes: Int,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(label)
                .font(theme.currentFont.font(size: 11, weight: .medium))
                .foregroundColor(theme.colors.text)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(theme.currentFont.font(size: 9, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 19, height: 19)
                        .background(theme.colors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
                .disabled(!viewModel.isIdle)
                .hoverEffect()

                Text("\(minutes) min")
                    .font(theme.currentFont.font(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.colors.text)
                    .frame(width: 44)

                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus")
                        .font(theme.currentFont.font(size: 9, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 19, height: 19)
                        .background(theme.colors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(SpringButtonStyle(kind: .secondary, theme: theme))
                .disabled(!viewModel.isIdle)
                .hoverEffect()
            }
            .opacity(viewModel.isIdle ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DISPLAY")

            VStack(spacing: 0) {
                // Font Picker
            VStack(spacing: 5) {
                    Text("Timer Font")
                        .font(theme.currentFont.font(size: 8, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)

                    ForEach(AppFont.allCases) { appFont in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                theme.currentFont = appFont
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(appFont.rawValue)
                                    .font(appFont.font(size: 11, weight: .medium))
                                    .foregroundColor(
                                        theme.currentFont == appFont
                                            ? theme.colors.text
                                            : theme.colors.textSecondary
                                    )

                                Spacer()

                                if theme.currentFont == appFont {
                                    Image(systemName: "checkmark")
                                        .font(theme.currentFont.font(size: 9, weight: .bold))
                                        .foregroundColor(theme.colors.accent)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .background(
                                theme.currentFont == appFont
                                    ? theme.colors.accent.opacity(0.08)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .hoverEffect()
                    }
                }
                .padding(.bottom, 6)

                if theme.currentFont != .system {
                    Divider().background(theme.colors.ringTrack)

                    // Font Weight (Inter only)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Font Weight")
                                .font(theme.currentFont.font(size: 11, weight: .medium))
                                .foregroundColor(theme.colors.text)

                            Spacer()

                            Text(theme.fontWeightLabel(theme.interFontWeightBoost))
                                .font(theme.currentFont.font(size: 10, weight: .medium))
                                .foregroundColor(theme.colors.accent)
                        }

                        Slider(value: Binding(
                            get: { Double(theme.interFontWeightBoost) },
                            set: { newValue in
                                theme.interFontWeightBoost = Int(newValue)
                            }
                        ), in: 0...3, step: 1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
        }
    }

    // MARK: - Theme Section
    
    private var themeMenuButton: some View {
        Button {
            onShowThemePicker(themeButtonFrame)
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(theme.currentTheme.previewColor)
                    .frame(width: 7, height: 7)

                Text(theme.currentTheme.rawValue)
                    .font(theme.currentFont.font(size: 11, weight: .medium))
                    .foregroundColor(theme.colors.text)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(theme.currentFont.font(size: 8, weight: .semibold))
                    .foregroundColor(theme.colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ThemeButtonFramePreferenceKey.self, value: geo.frame(in: .named("panel")))
            }
        )
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WINDOW")

            VStack(spacing: 0) {
                HStack {
                    Text("Always on Top")
                        .font(theme.currentFont.font(size: 11, weight: .medium))
                        .foregroundColor(theme.colors.text)

                    Spacer()

                    // AppDelegate observes this default and updates the panel level.
                    Toggle("", isOn: $alwaysOnTop)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

                Divider().background(theme.colors.ringTrack)

                HStack {
                    Text("Timer in Menu Bar")
                        .font(theme.currentFont.font(size: 11, weight: .medium))
                        .foregroundColor(theme.colors.text)

                    Spacer()

                    Toggle("", isOn: $showTimerInMenuBar)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

            }
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
        }
    }

    // MARK: - Data Management

    private var resetButton: some View {
        Button {
            showingResetAlert = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(theme.currentFont.font(size: 10))
                Text("Reset Statistics")
                    .font(theme.currentFont.font(size: 11, weight: .medium))
            }
            .foregroundColor(Color(nsColor: NSColor(red: 0.85, green: 0.4, blue: 0.2, alpha: 1)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
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
            HStack(spacing: 5) {
                Image(systemName: "power")
                    .font(theme.currentFont.font(size: 10))
                Text("Quit PCVL")
                    .font(theme.currentFont.font(size: 11, weight: .medium))
            }
            .foregroundColor(Color(nsColor: NSColor(red: 0.85, green: 0.3, blue: 0.3, alpha: 1)))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(theme.currentFont.font(size: 8, weight: .semibold))
            .tracking(1.5)
            .foregroundColor(theme.colors.textSecondary)
    }

}
