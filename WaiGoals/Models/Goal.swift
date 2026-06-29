import Foundation
import SwiftData

/// A goal/habit the user wants to keep up. Enum-like fields are stored as
/// primitives (Int/String/[Int]) to avoid SwiftData's pitfalls with custom
/// Codable enums, and bridged to value types via computed properties.
@Model
final class Goal {
    var id: UUID = UUID()
    var title: String = ""
    /// SF Symbol name shown as the goal's icon.
    var symbol: String = "target"
    /// `AccentToken.rawValue`.
    var colorToken: String = AccentToken.default.rawValue

    /// `ScheduleType.rawValue`.
    var scheduleTypeRaw: Int = ScheduleType.daily.rawValue
    /// `Calendar` weekday ints (1...7) for `.specificDays`.
    var scheduledWeekdaysRaw: [Int] = []
    /// Weekly target for `.timesPerWeek`.
    var weeklyTarget: Int = 3

    var reminderEnabled: Bool = false
    /// Time-of-day for the reminder; only hour/minute components are used.
    var reminderTime: Date?

    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Completion.goal)
    var completions: [Completion] = []

    @Relationship(deleteRule: .cascade, inverse: \Intention.goal)
    var intentions: [Intention] = []

    init(
        id: UUID = UUID(),
        title: String,
        symbol: String = "target",
        color: AccentToken = .default,
        schedule: Schedule = .daily,
        reminderEnabled: Bool = false,
        reminderTime: Date? = nil,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.colorToken = color.rawValue
        self.scheduleTypeRaw = schedule.type.rawValue
        self.scheduledWeekdaysRaw = schedule.weekdays.map(\.rawValue).sorted()
        self.weeklyTarget = schedule.timesPerWeek
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.completions = []
        self.intentions = []
    }
}

// MARK: - Value-type bridges

extension Goal {
    var schedule: Schedule {
        get {
            Schedule(
                type: ScheduleType(rawValue: scheduleTypeRaw) ?? .daily,
                weekdays: Set(scheduledWeekdaysRaw.compactMap(Weekday.init(rawValue:))),
                timesPerWeek: weeklyTarget
            )
        }
        set {
            scheduleTypeRaw = newValue.type.rawValue
            scheduledWeekdaysRaw = newValue.weekdays.map(\.rawValue).sorted()
            weeklyTarget = newValue.timesPerWeek
        }
    }

    var accent: AccentToken { AccentToken(rawValue: colorToken) ?? .default }
}

// MARK: - Completion helpers

extension Goal {
    /// Completed days normalized to local start-of-day.
    func completedDays(calendar: Calendar = .current) -> Set<Date> {
        Set(completions.map { calendar.startOfDay(for: $0.day) })
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        let target = calendar.startOfDay(for: date)
        return completions.contains { calendar.isDate($0.day, inSameDayAs: target) }
    }

    func intention(on date: Date, calendar: Calendar = .current) -> Intention? {
        let target = calendar.startOfDay(for: date)
        return intentions.first { calendar.isDate($0.day, inSameDayAs: target) }
    }

    func hasIntention(on date: Date, calendar: Calendar = .current) -> Bool {
        intention(on: date, calendar: calendar) != nil
    }

    /// Whether the goal should appear in the "Today" list: due today and, for
    /// weekly goals, not yet at target (still actionable).
    func isDue(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isArchived else { return false }
        return schedule.isScheduled(on: date, calendar: calendar)
    }

    func streak(asOf today: Date = .now, calendar: Calendar = .current) -> StreakResult {
        StreakCalculator.streak(schedule: schedule, completedDays: completedDays(calendar: calendar),
                                asOf: today, calendar: calendar)
    }
}
