import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Goal.sortIndex) private var goals: [Goal]
    private let calendar = Calendar.current

    private var active: [Goal] { goals.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if active.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
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
            VStack(spacing: Theme.Spacing.l) {
                weekHero
                tiles
                trendCard
                leaderboardCard
            }
            .padding(Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    private var weekHero: some View {
        let done = weekTotals.done
        let total = weekTotals.total
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        return HStack(spacing: Theme.Spacing.xl) {
            ZStack {
                ProgressRing(fraction: fraction, lineWidth: 11)
                    .frame(width: 92, height: 92)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("This week's completion")
            .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            VStack(alignment: .leading, spacing: 4) {
                Text("This week").font(.title3.weight(.semibold))
                Text("\(done) of \(total) check-ins done")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .card(cornerRadius: Theme.Radius.hero)
    }

    // MARK: - Tiles

    private var tiles: some View {
        HStack(spacing: Theme.Spacing.m) {
            statTile(value: "\(active.count)", label: "Goals", symbol: "flag.fill",
                     tint: AccentToken.indigo.color)
            statTile(value: "\(longestStreak)", label: "Best streak", symbol: "flame.fill",
                     tint: AccentToken.amber.partnerColor)
            statTile(value: "\(totalCompletions)", label: "Check-ins", symbol: "checkmark.seal.fill",
                     tint: AccentToken.green.color)
        }
    }

    private func statTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(tint)
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
        .padding(.vertical, Theme.Spacing.l)
        .card(cornerRadius: Theme.Radius.button)
    }

    // MARK: - Trend

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Last 12 weeks").font(.headline)
            TrendChartView(points: aggregateTrend)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Current streaks").font(.headline)
            VStack(spacing: Theme.Spacing.m) {
                ForEach(streakRanking, id: \.0.id) { goal, streak in
                    HStack(spacing: Theme.Spacing.m) {
                        GoalIcon(symbol: goal.symbol, accent: goal.accent, size: 34)
                        Text(goal.title).font(.subheadline.weight(.medium)).lineLimit(1)
                        Spacer(minLength: Theme.Spacing.s)
                        StreakBadge(count: streak.current, unit: streak.unit, tint: goal.accent.color, showsLabel: true)
                    }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
}
