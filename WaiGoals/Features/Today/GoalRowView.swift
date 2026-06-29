import SwiftUI

/// A goal as it appears in the Today list. The leading check and the rest of the
/// row are *separate* controls so "mark done" and "open details" are distinct,
/// unambiguous actions for both touch and VoiceOver.
struct TodayGoalRow: View {
    let goal: Goal
    let isDone: Bool
    let intentionCue: IntentionCue?
    var calendar: Calendar = .current
    let onToggle: () -> Void
    let onIntend: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            CompletionButton(isDone: isDone, symbol: goal.symbol, tint: tint, size: 46, action: onToggle)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
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

                if isDone, let intentionCue {
                    Label("Intended: \(intentionCue.title)", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !isDone {
                    Button(action: onIntend) {
                        Label(intentionTitle, systemImage: intentionCue == nil ? "target" : "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, Theme.Spacing.m)
                            .frame(minHeight: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(intentionCue == nil ? tint.opacity(0.10) : tint.opacity(0.16))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(tint.opacity(intentionCue == nil ? 0.28 : 0.55), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(tint)
                    .accessibilityLabel(intentionAccessibilityLabel)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .card()
    }

    private var intentionTitle: String {
        guard let intentionCue else { return "Intend today" }
        return "Intended: \(intentionCue.title)"
    }

    private var intentionAccessibilityLabel: String {
        guard let intentionCue else { return "Approve intention for \(goal.title)" }
        return "Change intention for \(goal.title), currently \(intentionCue.title)"
    }

    private func accessibilityLabel(streak: StreakResult) -> String {
        var parts = [goal.title, subtitle]
        if let intentionCue {
            parts.append("Intended for \(intentionCue.title)")
        }
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
