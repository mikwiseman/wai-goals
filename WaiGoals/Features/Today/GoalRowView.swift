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
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        HStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
            spacing: Theme.Spacing.s
        ) {
            CompletionButton(
                isDone: isDone,
                symbol: goal.symbol,
                tint: tint,
                size: 34,
                action: onToggle
            )
            .accessibilityLabel(isDone ? "Mark \(goal.title) incomplete" : "Mark \(goal.title) complete")

            goalSummary(streak: streak)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(tint.opacity(isCelebrating ? 0.13 : 0))
        }
        .scaleEffect(reduceMotion || !isCelebrating ? 1 : 1.012)
        .animation(reduceMotion ? nil : WaiMotion.quick, value: isCelebrating)
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
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    Text(metadata(streak: streak))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                }
                Spacer(minLength: Theme.Spacing.s)
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

    private func metadata(streak: StreakResult) -> String {
        var parts = [subtitle]
        if streak.current > 0 {
            parts.append("\(streak.current) \(streak.unit.label(for: streak.current))")
        }
        if hasIntention, !isDone {
            parts.append("Intention set")
        }
        return parts.joined(separator: " · ")
    }
}
