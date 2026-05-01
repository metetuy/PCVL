import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var statsManager: StatisticsManager
    @ObservedObject var theme: ThemeManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                // Summary cards
                summaryRow
                    .padding(.top, 14)

                // Weekly chart
                weeklyChart
                    .padding(.horizontal, 16)

                // Recent sessions
                recentSessionsList
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(statsManager.todaySessions())",
                label: "Today",
                icon: "checkmark.circle"
            )
            statCard(
                value: "\(statsManager.todayFocusMinutes())m",
                label: "Focus",
                icon: "clock"
            )
            statCard(
                value: "\(statsManager.currentStreak())d",
                label: "Streak",
                icon: "flame"
            )
        }
        .padding(.horizontal, 16)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(theme.currentFont.font(size: 12))
                .foregroundColor(theme.colors.accent)
            Text(value)
                .font(theme.currentFont.font(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.colors.text)
            Text(label)
                .font(theme.currentFont.font(size: 9, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let data = statsManager.weeklyData()
        let maxMinutes = max(data.map(\.minutes).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(theme.currentFont.font(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(theme.colors.textSecondary)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                entry.isToday
                                    ? theme.colors.accent
                                    : theme.colors.accent.opacity(0.25)
                            )
                            .frame(
                                height: max(
                                    CGFloat(entry.minutes) / CGFloat(maxMinutes) * 60,
                                    entry.minutes > 0 ? 4 : 2
                                )
                            )

                        // Day label
                        Text(entry.day)
                            .font(theme.currentFont.font(size: 8, weight: entry.isToday ? .bold : .regular))
                            .foregroundColor(
                                entry.isToday
                                    ? theme.colors.text
                                    : theme.colors.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        let sessions = statsManager.recentSessions(limit: 15)

        return VStack(alignment: .leading, spacing: 8) {
            Text("RECENT")
                .font(theme.currentFont.font(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(theme.colors.textSecondary)

            if sessions.isEmpty {
                Text("No sessions yet")
                    .font(theme.currentFont.font(size: 12))
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                        sessionRow(session)

                        if index < sessions.count - 1 {
                            Divider()
                                .background(theme.colors.ringTrack)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sessionRow(_ session: SessionRecord) -> some View {
        HStack(spacing: 8) {
            // Type badge
            Circle()
                .fill(badgeColor(for: session.sessionType))
                .frame(width: 6, height: 6)

            // Date
            Text(formattedDate(session.date))
                .font(theme.currentFont.font(size: 11))
                .foregroundColor(theme.colors.text)

            Spacer()

            // Duration
            Text(session.durationFormatted)
                .font(theme.currentFont.font(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(theme.colors.textSecondary)

            // Type label
            Text(typeLabel(session.sessionType))
                .font(theme.currentFont.font(size: 9, weight: .medium))
                .foregroundColor(badgeColor(for: session.sessionType))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor(for: session.sessionType).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func badgeColor(for type: SessionType) -> Color {
        switch type {
        case .work: return theme.colors.timerRing
        case .shortBreak: return theme.colors.breakRing
        case .stopwatch: return theme.colors.accent
        }
    }

    private func typeLabel(_ type: SessionType) -> String {
        switch type {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .stopwatch: return "Free"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, HH:mm"
            return formatter.string(from: date)
        }
    }
}
