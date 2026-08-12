import SwiftUI

/// A goal as it appears in the Today list. The leading check and the rest of the
/// row are *separate* controls so "mark done" and "open details" are distinct,
/// unambiguous actions for both touch and VoiceOver.
///
/// The row is deliberately compact — one line of content — so a full day of six
/// goals fits on screen without scrolling.
struct TodayGoalRow: View {
    let goal: Goal
    /// The day this row represents; completions, streaks and weekly progress
    /// are all evaluated against it (Today can page into the past).
    var day: Date = .now
    /// Whether `day` is the actual today. Intentions are forward-looking, so the
    /// approve control only exists in the present.
    var isToday: Bool = true
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
        let streak = goal.streak(asOf: day, calendar: calendar)
        HStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
            spacing: Theme.Spacing.s
        ) {
            CompletionButton(
                isDone: isDone,
                symbol: goal.symbol,
                tint: tint,
                partnerTint: goal.accent.partnerColor,
                foreground: goal.accent.gradientForeground,
                size: 38,
                action: onToggle
            )
            .accessibilityLabel(isDone ? "Mark \(goal.title) incomplete" : "Mark \(goal.title) complete")

            goalSummary(streak: streak)

            if isToday, !isDone {
                intentionButton(tint: tint)
            } else if hasIntention {
                Image(systemName: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint.opacity(0.75))
                    .accessibilityLabel("Intention approved")
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.m)
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
                spacing: Theme.Spacing.s
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                }
                Spacer(minLength: Theme.Spacing.xs)
                if streak.current > 0 {
                    StreakBadge(count: streak.current, unit: streak.unit, tint: goal.accent.color)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.waiPressable(scale: 0.98))
        .accessibilityLabel(accessibilityLabel(streak: streak))
        .accessibilityHint("Opens details")
    }

    /// Compact seal control: `target` invites the day's commitment; once made it
    /// becomes the filled seal. Icon-only to keep the row one line tall — the
    /// full pledge lives in the approval sheet it opens.
    private func intentionButton(tint: Color) -> some View {
        Button(action: onIntend) {
            Image(systemName: hasIntention ? "checkmark.seal.fill" : "target")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, options: .nonRepeating,
                              value: reduceMotion ? false : hasIntention)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(tint.opacity(hasIntention ? 0.18 : 0.10))
                )
                .overlay(
                    Circle().strokeBorder(tint.opacity(hasIntention ? 0.55 : 0.30), lineWidth: 1)
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.waiPressable(scale: 0.85))
        .animation(reduceMotion ? nil : WaiMotion.quick, value: hasIntention)
        .accessibilityLabel(intentionAccessibilityLabel)
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
                asOf: day, calendar: calendar
            )
            return "\(progress.done)/\(progress.total) this week"
        }
        return goal.schedule.summary(calendar: calendar)
    }

}
