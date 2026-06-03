import SwiftUI

/// A goal as it appears in the Today list. The leading check and the rest of the
/// row are *separate* controls so "mark done" and "open details" are distinct,
/// unambiguous actions for both touch and VoiceOver.
struct TodayGoalRow: View {
    let goal: Goal
    let isDone: Bool
    var calendar: Calendar = .current
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        HStack(spacing: Theme.Spacing.m) {
            CompletionButton(isDone: isDone, symbol: goal.symbol, tint: tint, size: 46, action: onToggle)

            Button(action: onOpen) {
                HStack(spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.title)
                            .font(.body.weight(.semibold))
                            .strikethrough(isDone, color: .secondary)
                            .foregroundStyle(isDone ? .secondary : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.s)
                    if streak.current > 0 {
                        StreakBadge(count: streak.current, unit: streak.unit, tint: tint)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(streak: streak))
            .accessibilityHint("Opens details")
        }
        .padding(Theme.Spacing.l)
        .card()
    }

    private func accessibilityLabel(streak: StreakResult) -> String {
        var parts = [goal.title, subtitle]
        if streak.current > 0 {
            parts.append("\(streak.current) \(streak.unit.label(for: streak.current)) streak")
        }
        return parts.joined(separator: ", ")
    }

    private var subtitle: String {
        if goal.schedule.type == .timesPerWeek {
            let progress = StatsCalculator.currentWeekProgress(
                schedule: goal.schedule,
                completedDays: goal.completedDays(calendar: calendar),
                asOf: .now, calendar: calendar
            )
            return "\(progress.done)/\(progress.total) this week"
        }
        return goal.schedule.summary(calendar: calendar)
    }
}
