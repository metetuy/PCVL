import SwiftUI

struct StatsView: View {
    @ObservedObject var statsManager: StatisticsManager
    @ObservedObject var theme: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Statistics")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.colors.text)
                    .padding(.top, 16)

                // Today
                VStack(spacing: 8) {
                    Text("Today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)

                    HStack(spacing: 16) {
                        statCard(
                            value: "\(statsManager.todaySessions())",
                            label: "Sessions",
                            icon: "checkmark.circle"
                        )
                        statCard(
                            value: "\(statsManager.todayFocusMinutes())m",
                            label: "Focus Time",
                            icon: "clock"
                        )
                    }
                }

                Divider()
                    .padding(.horizontal)

                // All time
                VStack(spacing: 8) {
                    Text("All Time")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.colors.textSecondary)

                    HStack(spacing: 16) {
                        statCard(
                            value: "\(statsManager.totalSessionsCompleted())",
                            label: "Sessions",
                            icon: "flame"
                        )
                        statCard(
                            value: formatTotalTime(statsManager.totalFocusTime()),
                            label: "Focus Time",
                            icon: "hourglass"
                        )
                    }

                    HStack(spacing: 16) {
                        statCard(
                            value: "\(statsManager.currentStreak())",
                            label: "Day Streak",
                            icon: "bolt.fill"
                        )
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.colors.accent)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(theme.colors.text)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatTotalTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
