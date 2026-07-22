import SwiftUI

/// A goal as it appears in the Today list. The leading check and the rest of the
/// row are *separate* controls so "mark done" and "open details" are distinct,
/// unambiguous actions for both touch and VoiceOver.
struct TodayGoalRow: View {
    let goal: Goal
    let isDone: Bool
    let hasIntention: Bool
    var calendar: Calendar = .current
    let onToggle: () -> Void
    let onIntend: () -> Void
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = goal.accent.color
        let streak = goal.streak(asOf: .now, calendar: calendar)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    completionButton(tint: tint)
                    goalSummary(streak: streak, tint: tint, compact: false)
                    if streak.current > 0 {
                        StreakBadge(count: streak.current, unit: streak.unit,
                                    tint: tint, showsLabel: true)
                    }
                    supportingAction(tint: tint)
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    completionButton(tint: tint)
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        goalSummary(streak: streak, tint: tint, compact: true)
                        supportingAction(tint: tint)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    private func completionButton(tint: Color) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let emotion = goal.emotion {
                EmotionArtwork(emotion: emotion, size: 58, decorative: true)
                    .opacity(isDone ? 0.58 : 1)
                    .saturation(isDone ? 0.5 : 1)
            } else {
                GoalIcon(symbol: goal.symbol, tint: tint, size: 58)
            }
            CompletionButton(isDone: isDone, tint: tint, size: 28, action: onToggle)
                .background(Circle().fill(Color(.systemBackground)))
                .offset(x: 7, y: 7)
        }
        .frame(width: 66, height: 66)
        .animation(reduceMotion ? nil : WaiMotion.quick, value: isDone)
    }

    private func goalSummary(streak: StreakResult, tint: Color, compact: Bool) -> some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.body.weight(.semibold))
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .lineLimit(compact ? 1 : nil)
                        .minimumScaleFactor(compact ? 0.85 : 1)
                        .fixedSize(horizontal: false, vertical: !compact)
                    Text(subtitleWithEmotion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(compact ? 1 : nil)
                        .fixedSize(horizontal: false, vertical: !compact)
                }
                Spacer(minLength: Theme.Spacing.s)
                if compact, streak.current > 0 {
                    StreakBadge(count: streak.current, unit: streak.unit, tint: tint)
                }
                if compact {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(streak: streak))
        .accessibilityHint("Opens details")
    }

    @ViewBuilder
    private func supportingAction(tint: Color) -> some View {
        if isDone, hasIntention {
            Label("Intention approved", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        } else if !isDone {
            Button(action: onIntend) {
                Label(intentionTitle, systemImage: hasIntention ? "checkmark.seal.fill" : "target")
                    .font(.caption.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    .padding(.horizontal, Theme.Spacing.xxs)
            }
            .waiGlassButton()
            .controlSize(dynamicTypeSize.isAccessibilitySize ? .regular : .small)
            .tint(hasIntention ? tint : .secondary)
            .foregroundStyle(tint)
            .accessibilityLabel(intentionAccessibilityLabel)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                   alignment: .leading)
        }
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

    private var subtitleWithEmotion: String {
        guard let emotion = goal.emotion else { return subtitle }
        return "\(subtitle) · \(emotion.displayName)"
    }
}
