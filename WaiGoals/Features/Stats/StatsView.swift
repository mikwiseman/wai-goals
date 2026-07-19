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
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                summarySurface

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(title: "Momentum", detail: "Last 12 weeks")
                    trendCard
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SectionHeading(title: "Goals in motion", detail: "Current streaks")
                    leaderboardCard
                }
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
        return HStack(spacing: Theme.Spacing.l) {
            ZStack {
                ProgressRing(fraction: fraction, lineWidth: 11)
                    .frame(width: 84, height: 84)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("This week's completion")
            .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
            VStack(alignment: .leading, spacing: 4) {
                Text("Toward your goals")
                    .font(.title3.weight(.semibold))
                Text("\(done) of \(total) check-ins done")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tiles

    private var tiles: some View {
        HStack(spacing: Theme.Spacing.s) {
            statTile(value: "\(active.count)", label: "Goals", symbol: "flag.fill")
            Divider().frame(height: 52)
            statTile(value: "\(longestStreak)", label: "Best streak", symbol: "flame.fill")
            Divider().frame(height: 52)
            statTile(value: "\(totalCompletions)", label: "Check-ins", symbol: "checkmark.seal.fill")
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

    // MARK: - Leaderboard

    private var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(streakRanking.enumerated()), id: \.element.0.id) { index, item in
                let goal = item.0
                let streak = item.1
                HStack(spacing: Theme.Spacing.m) {
                    GoalIcon(symbol: goal.symbol, tint: goal.accent.color, size: 40)
                    Text(goal.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.s)
                    StreakBadge(count: streak.current, unit: streak.unit,
                                tint: goal.accent.color, showsLabel: true)
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
