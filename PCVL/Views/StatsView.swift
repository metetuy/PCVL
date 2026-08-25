import SwiftUI

// MARK: - Stats View

struct StatsView: View {
    @ObservedObject var statsManager: StatisticsManager
    @ObservedObject var theme: ThemeManager

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                // Summary cards
                summaryRow
                    .padding(.top, 10)

                // Weekly chart
                weeklyChart
                    .padding(.horizontal, 14)

                // Recent sessions
                recentSessionsList
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 8) {
            statCard(
                value: "\(statsManager.todaySessions())",
                label: "Sessions"
            )
            statCard(
                value: "\(statsManager.todayFocusMinutes())m",
                label: "Focus"
            )
            statCard(
                value: "\(statsManager.currentStreak())d",
                label: "Streak",
                valueColor: theme.colors.accent
            )
        }
        .padding(.horizontal, 14)
    }

    private func statCard(value: String, label: String, valueColor: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(theme.currentFont.font(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(valueColor ?? theme.colors.text)
            Text(label.uppercased())
                .font(theme.currentFont.font(size: 8, weight: .medium))
                .foregroundColor(theme.colors.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let data = statsManager.weeklyData()
        let maxMinutes = max(data.map(\.minutes).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK")
                .font(theme.currentFont.font(size: 8, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(theme.colors.textSecondary)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 3) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                entry.isToday
                                    ? theme.colors.accent
                                    : theme.colors.accent.opacity(0.25)
                            )
                            .frame(
                                height: max(
                                    CGFloat(entry.minutes) / CGFloat(maxMinutes) * 46,
                                    entry.minutes > 0 ? 4 : 2
                                )
                            )

                        // Day label
                        Text(entry.day)
                            .font(theme.currentFont.font(size: 7, weight: entry.isToday ? .bold : .regular))
                            .foregroundColor(
                                entry.isToday
                                    ? theme.colors.text
                                    : theme.colors.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 62)
            .padding(.vertical, 6)
            .padding(.horizontal, 3)
        }
        .padding(10)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        let sessions = statsManager.recentSessions(limit: 15)

        return VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(theme.currentFont.font(size: 8, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(theme.colors.textSecondary)

            if sessions.isEmpty {
                Text("No sessions yet")
                    .font(theme.currentFont.font(size: 11))
                    .foregroundColor(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
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
        .padding(10)
        .background(theme.colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.text.opacity(0.06), lineWidth: 0.5))
    }

    private func sessionRow(_ session: SessionRecord) -> some View {
        HStack(spacing: 7) {
            // Type badge
            Circle()
                .fill(badgeColor(for: session.sessionType))
                .frame(width: 5, height: 5)

            // Date
            Text(formattedDate(session.date))
                .font(theme.currentFont.font(size: 10))
                .foregroundColor(theme.colors.text)

            Spacer()

            // Duration
            Text(session.durationFormatted)
                .font(theme.currentFont.font(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(theme.colors.textSecondary)

            // Type label
            Text(typeLabel(session.sessionType))
                .font(theme.currentFont.font(size: 8, weight: .medium))
                .foregroundColor(badgeColor(for: session.sessionType))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(badgeColor(for: session.sessionType).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 5)
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
