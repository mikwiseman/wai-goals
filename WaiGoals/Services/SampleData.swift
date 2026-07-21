import Foundation
import SwiftData

/// Seeds realistic, "today"-relative demo data. Used for screenshots/dev via the
/// `-seedSampleData` launch argument and the Settings → Developer tools. Real
/// users start with a clean, empty app.
enum SampleData {

    static func seedIfNeeded(_ context: ModelContext, calendar: Calendar = .current) {
        let count = (try? context.fetchCount(FetchDescriptor<Goal>())) ?? 0
        guard count == 0 else { return }
        seed(context, calendar: calendar)
    }

    static func wipe(_ context: ModelContext) {
        try? context.delete(model: Intention.self)
        try? context.delete(model: Completion.self)
        try? context.delete(model: Goal.self)
        context.saveOrLog()
    }

    static func reseed(_ context: ModelContext, calendar: Calendar = .current) {
        wipe(context)
        seed(context, calendar: calendar)
    }

    static func seed(_ context: ModelContext, calendar: Calendar = .current) {
        var index = 0
        func makeGoal(_ title: String, _ symbol: String, _ color: AccentToken,
                      _ emotion: GoalEmotion, _ schedule: Schedule, reminderHour: Int? = nil) -> Goal {
            let reminder = reminderHour.map { hour in
                calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
            }
            let goal = Goal(title: title, symbol: symbol, color: color, emotion: emotion, schedule: schedule,
                            reminderEnabled: reminderHour != nil, reminderTime: reminder,
                            sortIndex: index)
            index += 1
            context.insert(goal)
            return goal
        }

        // 1. Daily, done today, healthy streak — Mik's own example.
        let stopWork = makeGoal("Stop working at 7 PM", "moon.stars.fill", .indigo,
                                .balance, .daily, reminderHour: 19)
        addDayOffsets(stopWork, Array(0...12), context, calendar) // 13-day streak incl. today

        // 2. Times per week — weekly streak, mid-week progress.
        let telegram = makeGoal("Post in Telegram", "paperplane.fill", .blue,
                                .connection, Schedule(type: .timesPerWeek, timesPerWeek: 3), reminderHour: 11)
        addDates(telegram, weeklyDates(weeksAgo: 3, perWeek: 3, calendar: calendar), context)
        addDates(telegram, currentWeekDates(count: 1, calendar: calendar), context) // 1/3 this week
        addIntention(telegram, context, calendar)

        // 3. Specific days (Mon/Wed/Fri).
        let workout = makeGoal("Morning workout", "figure.run", .green,
                               .energy, Schedule(type: .specificDays, weekdays: [.monday, .wednesday, .friday]),
                               reminderHour: 7)
        addDayOffsets(workout, scheduledOffsets(weekdays: [2, 4, 6], within: 40, includeToday: false, calendar: calendar),
                      context, calendar)

        // 4. Daily, big streak but undone today (grace) — actionable now.
        let read = makeGoal("Read 20 pages", "book.fill", .amber, .focus, .daily, reminderHour: 21)
        addDayOffsets(read, Array(1...34), context, calendar) // 34-day streak, today pending
        addIntention(read, context, calendar)

        // 5. Daily, just hit a milestone-ish streak, done today.
        let meditate = makeGoal("Meditate 10 min", "figure.mind.and.body", .teal, .calm, .daily, reminderHour: 8)
        addDayOffsets(meditate, Array(0...6), context, calendar) // 7-day streak incl. today

        // 6. Daily, recovering streak (a recent miss), undone today.
        let phone = makeGoal("No phone after midnight", "iphone.slash", .violet, .courage, .daily)
        addDayOffsets(phone, [1, 2, 3, 5, 6, 7, 8, 9, 10], context, calendar) // missed day 4
        addIntention(phone, context, calendar)

        context.saveOrLog()
    }

    // MARK: - Helpers

    private static func addDayOffsets(_ goal: Goal, _ offsets: [Int],
                                      _ context: ModelContext, _ calendar: Calendar) {
        let today = calendar.startOfDay(for: .now)
        let dates = offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        addDates(goal, dates, context)
    }

    private static func addDates(_ goal: Goal, _ dates: [Date], _ context: ModelContext,
                                 calendar: Calendar = .current) {
        for date in dates {
            let completion = Completion(day: calendar.startOfDay(for: date), goal: goal)
            context.insert(completion)
        }
    }

    private static func addIntention(_ goal: Goal, _ context: ModelContext, _ calendar: Calendar) {
        let intention = Intention(day: calendar.startOfDay(for: .now), goal: goal)
        context.insert(intention)
    }

    /// Day offsets within `within` days whose weekday is in `weekdays`.
    private static func scheduledOffsets(weekdays: Set<Int>, within: Int, includeToday: Bool,
                                         calendar: Calendar) -> [Int] {
        let today = calendar.startOfDay(for: .now)
        let lower = includeToday ? 0 : 1
        return (lower...within).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return weekdays.contains(calendar.component(.weekday, from: day))
        }
    }

    private static func weeklyDates(weeksAgo: Int, perWeek: Int, calendar: Calendar) -> [Date] {
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        var dates: [Date] = []
        for week in 1...weeksAgo {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: thisWeekStart) else { continue }
            for day in 0..<perWeek {
                if let date = calendar.date(byAdding: .day, value: day, to: weekStart) {
                    dates.append(date)
                }
            }
        }
        return dates
    }

    private static func currentWeekDates(count: Int, calendar: Calendar) -> [Date] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        let today = calendar.startOfDay(for: .now)
        var dates: [Date] = []
        for day in 0..<count {
            if let date = calendar.date(byAdding: .day, value: day, to: weekStart), date <= today {
                dates.append(date)
            }
        }
        return dates
    }
}
