import Foundation
@testable import WaiGoals

/// Deterministic calendar + date helpers so tests never depend on the machine's
/// locale, timezone, or "now".
enum Cal {
    /// Gregorian, Monday-first, fixed timezone — stable week boundaries.
    static func make(firstWeekday: Int = 2, timeZone: String = "America/New_York") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timeZone)!
        c.firstWeekday = firstWeekday
        return c
    }

    static func day(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Build a set of start-of-day dates from (y,m,d) tuples.
    static func days(_ tuples: [(Int, Int, Int)], in calendar: Calendar) -> Set<Date> {
        Set(tuples.map { calendar.startOfDay(for: day($0.0, $0.1, $0.2, in: calendar)) })
    }
}
