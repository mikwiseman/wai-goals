import SwiftUI

/// A goal as it appears in the Today list. The leading check and the rest of the
/// row are *separate* controls so "mark done" and "open details" are distinct,
/// unambiguous actions for both touch and VoiceOver.
struct TodayGoalRow: View {
    let goal: Goal
    let isDone: Bool
    let hasIntention: Bool
    let isCelebrating: Bool
    var calendar: Calendar = .current
    let onToggle: () -> Void
    let onIntend: () -> Void
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        HStack(
            alignment: .top,
            spacing: Theme.Spacing.m
        ) {
            CompletionButton(
                isDone: isDone,
                symbol: goal.symbol,
                tint: tint,
                partnerTint: goal.accent.partnerColor,
                foreground: goal.accent.gradientForeground,
                size: 46,
                action: onToggle
            )
            .accessibilityLabel(isDone ? "Mark \(goal.title) incomplete" : "Mark \(goal.title) complete")

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                goalSummary(streak: streak)

                if isDone, hasIntention {
                    Label("Intention approved", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                } else if !isDone {
                    Button(action: onIntend) {
                        Label(
                            intentionTitle,
                            systemImage: hasIntention ? "checkmark.seal.fill" : "target"
                        )
                        .font(.caption.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, Theme.Spacing.m)
                        .frame(minHeight: 34)
                        .background(
                            Capsule(style: .continuous)
                                .fill(hasIntention ? tint.opacity(0.16) : tint.opacity(0.10))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(tint.opacity(hasIntention ? 0.55 : 0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(tint)
                    .accessibilityLabel(intentionAccessibilityLabel)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background {
            if isCelebrating {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(tint.opacity(0.13))
            }
        }
        .scaleEffect(reduceMotion || !isCelebrating ? 1 : 1.012)
        .animation(reduceMotion ? nil : WaiMotion.quick, value: isCelebrating)
        .card(tint: tint)
    }

    private func goalSummary(streak: StreakResult) -> some View {
        Button(action: onOpen) {
            HStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
                spacing: Theme.Spacing.m
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.body.weight(.semibold))
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                }
                Spacer(minLength: Theme.Spacing.s)
                if streak.current > 0 {
                    StreakBadge(count: streak.current, unit: streak.unit, tint: goal.accent.color)
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

    private var intentionTitle: String {
        hasIntention ? "Intention approved" : "Approve intention"
    }

    private var intentionAccessibilityLabel: String {
        hasIntention ? "Review intention for \(goal.title)" : "Approve intention for \(goal.title)"
    }

    private func accessibilityLabel(streak: StreakResult) -> String {
        var parts = [goal.title, subtitle]
        if hasIntention {
            parts.append("Intention approved")
        }
        if let emotion = goal.emotion {
            parts.append("Toward \(emotion.displayName)")
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
