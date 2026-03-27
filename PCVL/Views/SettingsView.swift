import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager
    @ObservedObject var statsManager: StatisticsManager

    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = false
    @State private var showingResetAlert = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Timer durations
                timerSection
                    .padding(.top, 14)

                // Theme picker
                themeSection

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
                    minutes: viewModel.workDuration / 60,
                    onDecrement: {
                        let newVal = max(5, viewModel.workDuration / 60 - 5) * 60
                        viewModel.workDuration = newVal
                    },
                    onIncrement: {
                        let newVal = min(480, viewModel.workDuration / 60 + 5) * 60
                        viewModel.workDuration = newVal
                    }
                )

                Divider().background(theme.colors.ringTrack)

                durationRow(
                    label: "Break",
                    icon: "cup.and.saucer",
                    minutes: viewModel.breakDuration / 60,
                    onDecrement: {
                        let newVal = max(1, viewModel.breakDuration / 60 - 1) * 60
                        viewModel.breakDuration = newVal
                    },
                    onIncrement: {
                        let newVal = min(30, viewModel.breakDuration / 60 + 1) * 60
                        viewModel.breakDuration = newVal
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
                .font(.system(size: 12))
                .foregroundColor(theme.colors.accent)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.colors.text)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    onDecrement()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.colors.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(theme.colors.background)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isIdle)

                Text("\(minutes) min")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.colors.text)
                    .frame(width: 50)

                Button {
                    onIncrement()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
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

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("THEME")

            VStack(spacing: 6) {
                ForEach(AppTheme.allCases) { appTheme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            theme.currentTheme = appTheme
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(previewColor(for: appTheme))
                                .frame(width: 10, height: 10)

                            Text(appTheme.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(
                                    theme.currentTheme == appTheme
                                        ? theme.colors.text
                                        : theme.colors.textSecondary
                                )

                            Spacer()

                            if theme.currentTheme == appTheme {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(theme.colors.accent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            theme.currentTheme == appTheme
                                ? theme.colors.accent.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(theme.colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("WINDOW")

            HStack {
                Image(systemName: "pin")
                    .font(.system(size: 12))
                    .foregroundColor(theme.colors.accent)
                    .frame(width: 20)

                Text("Always on Top")
                    .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 11))
                Text("Reset Statistics")
                    .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 11))
                Text("Quit PCVL")
                    .font(.system(size: 12, weight: .medium))
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
            .font(.system(size: 9, weight: .semibold))
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
        }
    }
}
