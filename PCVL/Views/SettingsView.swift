import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @ObservedObject var theme: ThemeManager

    @State private var workMinutes: Double = 25
    @State private var breakMinutes: Double = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .padding(.top, 16)

                // Timer durations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)

                    VStack(spacing: 8) {
                        HStack {
                            Text("Work")
                                .foregroundColor(theme.colors.text)
                            Spacer()
                            Text("\(Int(workMinutes)) min")
                                .foregroundColor(theme.colors.textSecondary)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        Slider(value: $workMinutes, in: 1...60, step: 1)
                            .tint(theme.colors.accent)
                            .onChange(of: workMinutes) { _, newValue in
                                viewModel.updateWorkDuration(Int(newValue))
                            }
                    }
                    .padding(12)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(spacing: 8) {
                        HStack {
                            Text("Break")
                                .foregroundColor(theme.colors.text)
                            Spacer()
                            Text("\(Int(breakMinutes)) min")
                                .foregroundColor(theme.colors.textSecondary)
                                .font(.system(size: 13, design: .monospaced))
                        }
                        Slider(value: $breakMinutes, in: 1...30, step: 1)
                            .tint(theme.colors.breakRing)
                            .onChange(of: breakMinutes) { _, newValue in
                                viewModel.updateBreakDuration(Int(newValue))
                            }
                    }
                    .padding(12)
                    .background(theme.colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Theme picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(AppTheme.allCases) { appTheme in
                            Button {
                                theme.currentTheme = appTheme
                            } label: {
                                Text(appTheme.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(
                                        theme.currentTheme == appTheme
                                            ? theme.colors.accent
                                            : theme.colors.textSecondary
                                    )
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        theme.currentTheme == appTheme
                                            ? theme.colors.accent.opacity(0.15)
                                            : theme.colors.surface
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // Quit button
                Button {
                    NSApp.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit PCVL")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            workMinutes = Double(viewModel.workMinutes)
            breakMinutes = Double(viewModel.breakMinutes)
        }
    }
}
