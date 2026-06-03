import Foundation

/// The state of a single calendar day for one goal, used by heatmaps and
/// week-strip views.
enum DayState: Sendable, Equatable {
    case notScheduled    // goal not due this day
    case completed       // due (or counted) and done
    case missed          // due in the past and not done
    case future          // after today
    case todayPending    // due today, not done yet (grace)

    /// Spoken description for VoiceOver.
    var accessibilityDescription: String {
        switch self {
        case .notScheduled: "Not scheduled"
        case .completed: "Completed"
        case .missed: "Missed"
        case .future: "Upcoming"
        case .todayPending: "Not done yet"
        }
    }
}

/// Pure, schedule-aware statistics derived from a goal's completion history.
/// Mirrors `StreakCalculator`'s "grace for today / this week" philosophy so the
/// numbers never punish an in-progress period.
enum StatsCalculator {

    // MARK: - Per-day state (heatmap / week strip)

    /// - Note: `completedDays` is expected to already be normalized to local
    ///   start-of-day (as produced by `Goal.completedDays`). The membership test
    ///   is therefore an O(1) exact lookup, consistent with `StreakCalculator`
    ///   and `completionRate` — they all compare normalized start-of-day values,
    ///   so the heatmap can never disagree with the streak.
    static func dayState(
        schedule: Schedule,
        completedDays: Set<Date>,
        on day: Date,
        asOf today: Date = .now,
        calendar: Calendar = .current
    ) -> DayState {
        let d = calendar.startOfDay(for: day)
        let t = calendar.startOfDay(for: today)
        let done = completedDays.contains(d)

        switch schedule.type {
        case .daily, .specificDays:
            if !schedule.isScheduled(on: d, calendar: calendar) {
                // For .timesPerWeek every day is "scheduled"; here it isn't.
                return done ? .completed : .notScheduled
            }
            if done { return .completed }
            if d > t { return .future }
            if d == t { return .todayPending }
            return .missed
        case .timesPerWeek:
            // Any day can contribute; only "completed" vs neutral is meaningful.
            if done { return .completed }
            if d > t { return .future }
            return .notScheduled
        }
    }

    // MARK: - Completion rate (0...1)

    /// Fraction of required occurrences completed within `[from, to]`.
    /// In-progress periods (an undone today / current week) are excluded from
    /// the denominator so the rate is never dragged down by grace time.
    static func completionRate(
        schedule: Schedule,
        completedDays: Set<Date>,
        from: Date,
        to: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let start = calendar.startOfDay(for: from)
        let today = calendar.startOfDay(for: to)
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) })

        switch schedule.type {
        case .daily, .specificDays:
            var due = 0, done = 0
            var day = start
            while day <= today {
                if schedule.isScheduled(on: day, calendar: calendar) {
                    let isDone = days.contains(day)
                    if day == today && !isDone {
                        // grace: ignore an undone today
                    } else {
                        due += 1
                        if isDone { done += 1 }
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return due == 0 ? 0 : Double(done) / Double(due)

        case .timesPerWeek:
            let target = schedule.timesPerWeek
            guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
                  var week = calendar.dateInterval(of: .weekOfYear, for: start)?.start
            else { return 0 }
            var perWeek: [Date: Int] = [:]
            for d in days where d >= start && d <= today {
                if let ws = calendar.dateInterval(of: .weekOfYear, for: d)?.start {
                    perWeek[ws, default: 0] += 1
                }
            }
            var due = 0, done = 0
            while week < currentWeek {
                due += target
                done += min(perWeek[week] ?? 0, target)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
                week = next
            }
            if due == 0 {
                // Only the current (in-progress) week exists; show its progress.
                let count = perWeek[currentWeek] ?? 0
                return min(Double(count) / Double(target), 1)
            }
            return Double(done) / Double(due)
        }
    }

    // MARK: - Weekly trend (for charts)

    struct WeekPoint: Identifiable, Equatable, Sendable {
        var id: Date { weekStart }
        var weekStart: Date
        var rate: Double // 0...1
    }

    /// The last `weeks` weeks (oldest → newest, including the current week),
    /// each with a completion rate suitable for a bar chart.
    static func weeklyTrend(
        schedule: Schedule,
        completedDays: Set<Date>,
        weeks: Int = 12,
        asOf today: Date = .now,
        calendar: Calendar = .current
    ) -> [WeekPoint] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) })
        let t = calendar.startOfDay(for: today)

        var points: [WeekPoint] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeek),
                  let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart)
            else { continue }

            switch schedule.type {
            case .daily, .specificDays:
                var due = 0, done = 0
                var day = interval.start
                while day < interval.end {
                    if day <= t, schedule.isScheduled(on: day, calendar: calendar) {
                        let isDone = days.contains(day)
                        if day == t && !isDone {
                            // grace
                        } else {
                            due += 1
                            if isDone { done += 1 }
                        }
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                }
                points.append(WeekPoint(weekStart: weekStart, rate: due == 0 ? 0 : Double(done) / Double(due)))
            case .timesPerWeek:
                let count = days.filter { $0 >= interval.start && $0 < interval.end }.count
                points.append(WeekPoint(weekStart: weekStart, rate: min(Double(count) / Double(schedule.timesPerWeek), 1)))
            }
        }
        return points
    }

    // MARK: - This-week progress (for rings)

    struct PeriodProgress: Equatable, Sendable {
        var done: Int
        var total: Int
        var fraction: Double { total == 0 ? 0 : min(Double(done) / Double(total), 1) }
        var isComplete: Bool { total > 0 && done >= total }
    }

    /// Progress within the current week.
    /// - day-based: total = required days this week up to & including today;
    ///   done = completed among them.
    /// - week-based: total = weekly target; done = completions this week.
    static func currentWeekProgress(
        schedule: Schedule,
        completedDays: Set<Date>,
        asOf today: Date = .now,
        calendar: Calendar = .current
    ) -> PeriodProgress {
        let t = calendar.startOfDay(for: today)
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) })
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: t) else {
            return PeriodProgress(done: 0, total: 0)
        }
        switch schedule.type {
        case .daily, .specificDays:
            var total = 0, done = 0
            var day = interval.start
            while day < interval.end {
                if day <= t, schedule.isScheduled(on: day, calendar: calendar) {
                    total += 1
                    if days.contains(day) { done += 1 }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return PeriodProgress(done: done, total: total)
        case .timesPerWeek:
            let count = days.filter { $0 >= interval.start && $0 < interval.end }.count
            return PeriodProgress(done: min(count, schedule.timesPerWeek), total: schedule.timesPerWeek)
        }
    }
}
