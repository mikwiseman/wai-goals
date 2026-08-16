import Foundation

/// How often a goal recurs.
enum ScheduleType: Int, Codable, Sendable, CaseIterable, Identifiable {
    case daily = 0          // every day
    case specificDays = 1   // on chosen weekdays
    case timesPerWeek = 2   // N times within a week, any days

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .specificDays: "Specific days"
        case .timesPerWeek: "Times per week"
        }
    }
}

/// The recurrence rule for a goal. A pure value type so all scheduling and
/// streak logic is testable without SwiftData.
struct Schedule: Equatable, Sendable {
    var type: ScheduleType
    /// Used when `type == .specificDays`.
    var weekdays: Set<Weekday>
    /// Used when `type == .timesPerWeek`. Clamped to 1...7.
    var timesPerWeek: Int

    init(type: ScheduleType, weekdays: Set<Weekday> = [], timesPerWeek: Int = 3) {
        self.type = type
        self.weekdays = weekdays
        self.timesPerWeek = min(max(timesPerWeek, 1), 7)
    }

    static let daily = Schedule(type: .daily)
    /// Every day except Saturday — the default for new goals.
    static let workdays = Schedule(type: .specificDays, weekdays: Weekday.workdays)

    /// Whether the goal is *due* on the given date.
    ///
    /// - `.daily`: always.
    /// - `.specificDays`: only on the chosen weekdays.
    /// - `.timesPerWeek`: actionable any day (the weekly target governs
    ///   completion, not the calendar day), so this returns `true`.
    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        switch type {
        case .daily:
            return true
        case .specificDays:
            return weekdays.contains(Weekday.from(date, calendar: calendar))
        case .timesPerWeek:
            return true
        }
    }

    /// Whether streaks for this schedule are counted in days or weeks.
    var streakUnit: StreakUnit {
        type == .timesPerWeek ? .week : .day
    }

    /// A short human description, e.g. "Daily", "Workdays", "Mon, Wed, Fri",
    /// "3× / week".
    func summary(calendar: Calendar = .current) -> String {
        switch type {
        case .daily:
            return "Daily"
        case .specificDays:
            if weekdays.isEmpty { return "No days" }
            if weekdays.count == 7 { return "Daily" }
            if weekdays == Weekday.workdays { return "Workdays" }
            let ordered = Weekday.ordered(firstWeekday: calendar.firstWeekday)
                .filter { weekdays.contains($0) }
            return ordered.map { $0.shortSymbol(calendar: calendar) }.joined(separator: ", ")
        case .timesPerWeek:
            return "\(timesPerWeek)× / week"
        }
    }
}
