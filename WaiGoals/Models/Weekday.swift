import Foundation

/// A day of the week, using the same integer raw values as `Calendar`'s
/// `.weekday` component for the Gregorian calendar (1 = Sunday … 7 = Saturday).
enum Weekday: Int, CaseIterable, Identifiable, Codable, Sendable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Workdays: every day except Saturday. The default schedule for new goals.
    static let workdays: Set<Weekday> = Set(allCases.filter { $0 != .saturday })

    /// The weekday for a given date in the supplied calendar.
    static func from(_ date: Date, calendar: Calendar = .current) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }

    /// All weekdays ordered so the supplied calendar's first weekday comes first
    /// (e.g. Monday-first locales). Used to lay out weekday pickers and headers.
    static func ordered(firstWeekday: Int) -> [Weekday] {
        (0..<7).map { offset in
            let raw = (firstWeekday - 1 + offset) % 7 + 1
            return Weekday(rawValue: raw) ?? .sunday
        }
    }

    /// Localized very short symbol, e.g. "M". Index is rawValue-1 into the
    /// calendar's symbol array.
    func veryShortSymbol(calendar: Calendar = .current) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.indices.contains(rawValue - 1) else { return "" }
        return symbols[rawValue - 1]
    }

    /// Localized short symbol, e.g. "Mon".
    func shortSymbol(calendar: Calendar = .current) -> String {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.indices.contains(rawValue - 1) else { return "" }
        return symbols[rawValue - 1]
    }
}
