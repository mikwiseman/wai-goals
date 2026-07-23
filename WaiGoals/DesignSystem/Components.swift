import SwiftUI

// MARK: - Milestones

/// Streak values worth celebrating.
enum Milestone {
    static let thresholds: [Int] = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 250, 300, 365]

    static func reached(_ n: Int) -> Bool {
        thresholds.contains(n) || (n > 365 && n % 100 == 0)
    }

    static func message(for n: Int, unit: StreakUnit) -> String {
        switch unit {
        case .day:
            switch n {
            case 0...6: return "A streak is forming. Keep showing up."
            case 7: return "A full week. This is becoming a habit."
            case 14...29: return "Two weeks and counting — momentum is real."
            case 30...99: return "A month-plus of consistency. Impressive."
            default: return "Extraordinary consistency. You own this now."
            }
        case .week:
            return n == 1 ? "First week hit. Onward." : "\(n) weeks of hitting your target. Strong."
        }
    }
}

// MARK: - Goal icon

struct GoalJourneyArtwork: View {
    var size: CGFloat = 88

    var body: some View {
        Image("GoalJourney")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .strokeBorder(.white.opacity(0.78), lineWidth: 0.75)
            }
            .accessibilityHidden(true)
    }
}

struct GoalIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.11))
            Image(systemName: symbol)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(.white.opacity(0.55), lineWidth: 0.75)
        }
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(.headline)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer(minLength: Theme.Spacing.m)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xxs)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 10
    var tint: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85), value: fraction)
        }
    }
}

// MARK: - Streak badge

struct StreakBadge: View {
    let count: Int
    var unit: StreakUnit = .day
    var tint: Color = .accentColor
    var showsLabel: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.footnote.weight(.semibold))
            Text("\(count)")
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            if showsLabel {
                Text(unit.label(for: count))
                    .font(.caption)
            }
        }
        .foregroundStyle(count > 0 ? AnyShapeStyle(tint) : AnyShapeStyle(Color.secondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count > 0 ? "\(count) \(unit.label(for: count)) streak" : "No streak yet")
    }
}

// MARK: - Completion button (the core interaction)

struct CompletionButton: View {
    let isDone: Bool
    /// When provided, the goal's SF Symbol shows inside the empty circle, so the
    /// single control reads as both the goal's icon and its check target.
    var symbol: String? = nil
    var tint: Color = .accentColor
    var size: CGFloat = 30
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isDone ? tint : Color.secondary.opacity(0.35), lineWidth: 2.5)
                    .frame(width: size, height: size)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(tint)
                        .opacity(isDone ? 0 : 0.9)
                        .scaleEffect(isDone ? 0.5 : 1)
                }
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .scaleEffect(isDone ? 1 : 0.01)
                    .opacity(isDone ? 1 : 0)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(isDone ? 1 : 0.2)
                    .opacity(isDone ? 1 : 0)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.6), value: isDone)
            .frame(minWidth: 44, minHeight: 44) // ensure a comfortable hit target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(trigger: isDone) { _, now in now ? .success : .impact(weight: .light) }
        .accessibilityLabel(isDone ? "Completed" : "Mark complete")
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }
}

// MARK: - Day dot & week strip

struct DayDot: View {
    let state: DayState
    var tint: Color = .accentColor
    var isToday: Bool = false
    var size: CGFloat = 26

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                if state == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: state == .completed)
                }
            }
            .overlay(
                Circle().strokeBorder(isToday ? tint : .clear, lineWidth: 2)
            )
    }

    private var fill: Color {
        switch state {
        case .completed: tint
        case .missed: Color.secondary.opacity(0.18)
        case .todayPending: tint.opacity(0.16)
        case .notScheduled, .future: Color.secondary.opacity(0.08)
        }
    }
}

struct WeekStrip: View {
    let schedule: Schedule
    let completedDays: Set<Date>
    var tint: Color = .accentColor
    var calendar: Calendar = .current

    var body: some View {
        let today = calendar.startOfDay(for: .now)
        let week = calendar.dateInterval(of: .weekOfYear, for: today)
        let days = (0..<7).compactMap { offset in
            week.flatMap { calendar.date(byAdding: .day, value: offset, to: $0.start) }
        }
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(days, id: \.self) { day in
                let state = StatsCalculator.dayState(schedule: schedule, completedDays: completedDays,
                                                     on: day, asOf: today, calendar: calendar)
                let isToday = calendar.isDate(day, inSameDayAs: today)
                VStack(spacing: 6) {
                    Text(Weekday.from(day, calendar: calendar).veryShortSymbol(calendar: calendar))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    DayDot(state: state, tint: tint, isToday: isToday)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
                .accessibilityValue(state.accessibilityDescription)
            }
        }
    }
}

// MARK: - Milestone celebration

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let spin: Double
    let delay: Double
}

struct ConfettiView: View {
    @State private var animate = false
    private let pieces: [ConfettiPiece]

    init(palette: [Color] = AccentToken.allCases.map(\.color), count: Int = 64) {
        pieces = (0..<count).map { index in
            ConfettiPiece(
                color: palette[index % palette.count],
                angle: Double.random(in: 0..<(2 * .pi)),
                distance: CGFloat.random(in: 90...240),
                size: CGFloat.random(in: 6...11),
                spin: Double.random(in: -360...360),
                delay: Double.random(in: 0...0.12)
            )
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.6)
                        .rotationEffect(.degrees(animate ? piece.spin : 0))
                        .offset(
                            x: animate ? cos(piece.angle) * piece.distance : 0,
                            y: animate ? sin(piece.angle) * piece.distance + 130 : 0
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).delay(piece.delay), value: animate)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.42)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

struct MilestoneOverlay: View {
    let streak: Int
    let unit: StreakUnit
    var tint: Color = .accentColor
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            if !reduceMotion {
                ConfettiView()
            }

            VStack(spacing: Theme.Spacing.l) {
                ZStack {
                    Circle()
                        .fill(tint.gradient)
                        .frame(width: 108, height: 108)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(spacing: 6) {
                    Text("\(streak) \(unit.label(for: streak)) in a row!")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(Milestone.message(for: streak, unit: unit))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button("Keep going", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .controlSize(.large)
            }
            .padding(Theme.Spacing.xxl)
            .frame(maxWidth: 320)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
            )
            .padding(Theme.Spacing.xxxl)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let symbol: String
    var emotion: GoalEmotion? = nil
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            if let emotion {
                EmotionArtwork(emotion: emotion, size: 104, animated: true, decorative: false)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(tint.gradient)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(spacing: Theme.Spacing.s) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .waiGlassButton(prominent: true)
                    .tint(tint)
                    .controlSize(.large)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: 360)
    }
}
