import Foundation

/// Whether a streak is measured in consecutive days or consecutive weeks.
enum StreakUnit: Sendable, Equatable {
    case day, week

    /// "day"/"days" or "week"/"weeks" for the given count.
    func label(for count: Int) -> String {
        switch self {
        case .day: count == 1 ? "day" : "days"
        case .week: count == 1 ? "week" : "weeks"
        }
    }
}

struct StreakResult: Equatable, Sendable {
    var current: Int
    var best: Int
    var unit: StreakUnit

    static let none = StreakResult(current: 0, best: 0, unit: .day)
}

/// Computes forgiving, schedule-aware streaks from a goal's completion history.
///
/// Design (grounded in habit-tracker UX research):
/// - Only *required* occurrences count. For `.specificDays`, unscheduled days
///   are skipped — they never break a streak. This makes non-daily goals
///   inherently forgiving.
/// - An as-yet-incomplete **today** (or current week) is grace, not a break:
///   the period isn't over, so the streak holds until it lapses.
/// - `best` is the longest run ever and is never reduced by a later miss.
/// - "Today" is device-local midnight via the supplied `Calendar`.
enum StreakCalculator {

    /// All inputs are normalized internally to local start-of-day.
    static func streak(
        schedule: Schedule,
        completedDays: Set<Date>,
        asOf today: Date = .now,
        calendar: Calendar = .current
    ) -> StreakResult {
        let normalizedToday = calendar.startOfDay(for: today)
        let days = Set(completedDays.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else {
            return StreakResult(current: 0, best: 0, unit: schedule.streakUnit)
        }

        switch schedule.type {
        case .daily, .specificDays:
            return dayBasedStreak(schedule: schedule, days: days,
                                  today: normalizedToday, calendar: calendar)
        case .timesPerWeek:
            return weekBasedStreak(target: schedule.timesPerWeek, days: days,
                                   today: normalizedToday, calendar: calendar)
        }
    }

    // MARK: - Day-based (.daily / .specificDays)

    private static func dayBasedStreak(
        schedule: Schedule, days: Set<Date>, today: Date, calendar: Calendar
    ) -> StreakResult {
        guard let earliest = days.min() else {
            return StreakResult(current: 0, best: 0, unit: .day)
        }

        // Current streak: walk backwards over scheduled days from today.
        var current = 0
        var cursor = today
        while cursor >= earliest {
            if schedule.isScheduled(on: cursor, calendar: calendar) {
                if days.contains(cursor) {
                    current += 1
                } else if cursor == today {
                    // Today not done yet — grace, keep walking.
                } else {
                    break // a past required day was missed → streak ends
                }
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        // Best streak: scan forward from the earliest completion to today.
        var best = 0
        var run = 0
        var day = earliest
        while day <= today {
            if schedule.isScheduled(on: day, calendar: calendar) {
                if days.contains(day) {
                    run += 1
                    best = max(best, run)
                } else if day == today {
                    // grace for today: neutral, don't reset
                } else {
                    run = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return StreakResult(current: current, best: max(best, current), unit: .day)
    }

    // MARK: - Week-based (.timesPerWeek)

    private static func weekBasedStreak(
        target: Int, days: Set<Date>, today: Date, calendar: Calendar
    ) -> StreakResult {
        // Count completions per week-start.
        var perWeek: [Date: Int] = [:]
        for day in days {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            perWeek[weekStart, default: 0] += 1
        }
        guard let earliestWeek = perWeek.keys.min(),
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start
        else { return StreakResult(current: 0, best: 0, unit: .week) }

        func satisfied(_ weekStart: Date) -> Bool { (perWeek[weekStart] ?? 0) >= target }

        // Current streak: walk backwards over weeks from the current week.
        var current = 0
        var week = currentWeek
        while week >= earliestWeek {
            if satisfied(week) {
                current += 1
            } else if week == currentWeek {
                // current week still in progress — grace
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = prev
        }

        // Best streak: scan forward over weeks.
        var best = 0
        var run = 0
        week = earliestWeek
        while week <= currentWeek {
            if satisfied(week) {
                run += 1
                best = max(best, run)
            } else if week == currentWeek {
                // grace for current week
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }

        return StreakResult(current: current, best: max(best, current), unit: .week)
    }
}
