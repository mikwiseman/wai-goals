import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = Calendar.current

    private var active: [Goal] { goals.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if active.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
                        emotion: .focus,
                        title: "No stats yet",
                        message: "Add goals and start checking them off — your streaks and trends will show up here."
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                summarySurface
                    .entranceMotion(order: 0)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(title: "Your impossible atlas", detail: "8 emotional worlds")
                    emotionMomentumStrip
                }
                .entranceMotion(order: 1)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(title: "Momentum", detail: "Last 12 weeks")
                    trendCard
                }
                .entranceMotion(order: 2)

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(title: "Goals in motion", detail: "Current streaks")
                    leaderboardCard
                }
                .entranceMotion(order: 3)
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.huge)
        }
        .scrollIndicators(.hidden)
    }

    private var summarySurface: some View {
        VStack(spacing: Theme.Spacing.xl) {
            weekHero
            Divider()
            tiles
        }
        .padding(Theme.Spacing.xl)
        .card(cornerRadius: Theme.Radius.hero)
    }

    // MARK: - Hero

    private var weekHero: some View {
        let done = weekTotals.done
        let total = weekTotals.total
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    weekProgressRing(fraction: fraction)
                        .frame(maxWidth: .infinity)
                    weekProgressCopy(done: done, total: total)
                }
            } else {
                HStack(spacing: Theme.Spacing.l) {
                    weekProgressRing(fraction: fraction)
                    weekProgressCopy(done: done, total: total)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekProgressRing(fraction: Double) -> some View {
        ZStack {
            EmotionArtwork(emotion: leadingEmotion, size: 100, animated: true)
            ProgressRing(fraction: fraction, lineWidth: 7, tint: leadingEmotion.worldTint)
                .frame(width: 112, height: 112)
            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.54), in: Capsule())
                .offset(y: 31)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week's completion")
        .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
    }

    private func weekProgressCopy(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Toward your goals")
                .font(.title3.weight(.semibold))
            Text("\(done) of \(total) check-ins done")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tiles

    private var tiles: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Theme.Spacing.l) {
                    statTile(value: "\(active.count)", label: "Goals", symbol: "flag.fill")
                    Divider()
                    statTile(value: "\(longestStreak)", label: "Best streak", symbol: "flame.fill")
                    Divider()
                    statTile(value: "\(totalCompletions)", label: "Check-ins", symbol: "checkmark.seal.fill")
                }
            } else {
                HStack(spacing: Theme.Spacing.s) {
                    statTile(value: "\(active.count)", label: "Goals", symbol: "flag.fill")
                    Divider().frame(height: 52)
                    statTile(value: "\(longestStreak)", label: "Best streak", symbol: "flame.fill")
                    Divider().frame(height: 52)
                    statTile(value: "\(totalCompletions)", label: "Check-ins", symbol: "checkmark.seal.fill")
                }
            }
        }
    }

    private func statTile(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            TrendChartView(points: aggregateTrend)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Emotional momentum

    private var emotionMomentumStrip: some View {
        let maximum = max(emotionMomentum.map(\.checkIns).max() ?? 0, 1)
        return ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(emotionMomentum) { item in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Image(decorative: item.emotion.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 154, height: 154)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                Text("\(item.checkIns)")
                                    .font(.caption.weight(.heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.54), in: Capsule())
                                    .padding(Theme.Spacing.xs)
                                    .contentTransition(.numericText())
                            }
                            .saturation(item.goalCount == 0 ? 0.16 : 1)
                            .opacity(item.goalCount == 0 ? 0.58 : 1)
                            .shadow(color: item.emotion.worldTint.opacity(item.goalCount == 0 ? 0.08 : 0.34),
                                    radius: 14, y: 8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.emotion.displayName)
                                .font(.subheadline.weight(.bold))
                            Text(item.goalCount == 0 ? "Unexplored" : item.emotion.feeling)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        ProgressView(value: Double(item.checkIns), total: Double(maximum))
                            .tint(.accentColor)
                    }
                    .padding(Theme.Spacing.m)
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 286 : 186, alignment: .leading)
                    .card()
                    .escherScrollDepth(axis: .horizontal)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.goalCount == 0
                                        ? "\(item.emotion.displayName), unexplored"
                                        : "\(item.emotion.displayName), \(item.checkIns) check-ins in the last 30 days")
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
        }
        .contentMargins(.horizontal, 1, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(streakRanking.enumerated()), id: \.element.0.id) { index, item in
                let goal = item.0
                let streak = item.1
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                                leaderboardArtwork(goal: goal)
                                Text(goal.title)
                                    .font(.subheadline.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            StreakBadge(count: streak.current, unit: streak.unit,
                                        tint: goal.accent.color, showsLabel: true)
                        }
                    } else {
                        HStack(spacing: Theme.Spacing.m) {
                            leaderboardArtwork(goal: goal)
                            Text(goal.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer(minLength: Theme.Spacing.s)
                            StreakBadge(count: streak.current, unit: streak.unit,
                                        tint: goal.accent.color, showsLabel: true)
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.m)

                if index < streakRanking.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private func leaderboardArtwork(goal: Goal) -> some View {
        if let emotion = goal.emotion {
            EmotionArtwork(emotion: emotion, size: 44, decorative: false)
        } else {
            GoalIcon(symbol: goal.symbol, tint: goal.accent.color, size: 40)
        }
    }

    // MARK: - Derived data

    private var weekTotals: (done: Int, total: Int) {
        active.reduce(into: (0, 0)) { acc, goal in
            let progress = StatsCalculator.currentWeekProgress(
                schedule: goal.schedule, completedDays: goal.completedDays(calendar: calendar),
                asOf: .now, calendar: calendar)
            acc.0 += progress.done
            acc.1 += progress.total
        }
    }

    private var longestStreak: Int {
        active.map { $0.streak(asOf: .now, calendar: calendar).best }.max() ?? 0
    }

    private var totalCompletions: Int {
        active.reduce(0) { $0 + $1.completions.count }
    }

    private var streakRanking: [(Goal, StreakResult)] {
        active
            .map { ($0, $0.streak(asOf: .now, calendar: calendar)) }
            .sorted { $0.1.current > $1.1.current }
    }

    private var aggregateTrend: [StatsCalculator.WeekPoint] {
        let perGoal = active.map {
            StatsCalculator.weeklyTrend(schedule: $0.schedule,
                                        completedDays: $0.completedDays(calendar: calendar),
                                        weeks: 12, asOf: .now, calendar: calendar)
        }
        guard let first = perGoal.first else { return [] }
        return (0..<first.count).map { index in
            let rates = perGoal.compactMap { $0.indices.contains(index) ? $0[index].rate : nil }
            let avg = rates.isEmpty ? 0 : rates.reduce(0, +) / Double(rates.count)
            return StatsCalculator.WeekPoint(weekStart: first[index].weekStart, rate: avg)
        }
    }

    private var emotionMomentum: [EmotionMomentum] {
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        return GoalEmotion.allCases.map { emotion in
            let matchingGoals = active.filter { $0.emotion == emotion }
            let checkIns = matchingGoals.reduce(0) { total, goal in
                total + goal.completions.filter {
                    let day = calendar.startOfDay(for: $0.day)
                    return day >= start && day <= today
                }.count
            }
            return EmotionMomentum(emotion: emotion, checkIns: checkIns,
                                   goalCount: matchingGoals.count)
        }
        .sorted {
            if ($0.goalCount > 0) != ($1.goalCount > 0) { return $0.goalCount > 0 }
            if $0.checkIns != $1.checkIns { return $0.checkIns > $1.checkIns }
            return $0.emotion.displayName < $1.emotion.displayName
        }
    }

    private var leadingEmotion: GoalEmotion {
        emotionMomentum.first(where: { $0.goalCount > 0 })?.emotion ?? .growth
    }
}

private struct EmotionMomentum: Identifiable {
    let emotion: GoalEmotion
    let checkIns: Int
    let goalCount: Int
    var id: GoalEmotion { emotion }
}
