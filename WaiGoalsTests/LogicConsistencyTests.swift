import Testing
import Foundation
@testable import WaiGoals

/// Locks the review fixes: the heatmap (`dayState`) and the streak engine must
/// agree, and week-based logic must work for non-Monday-first locales.
@Suite("Logic consistency")
struct LogicConsistencyTests {

    @Test("Heatmap dayState agrees with the streak for a completed run")
    func heatmapMatchesStreak() {
        let cal = Cal.make()
        let today = Cal.day(2025, 1, 15, in: cal) // Wed
        // Completed every day Jan 6...15 (10 days incl. today).
        let completed = Cal.days((6...15).map { (2025, 1, $0) }, in: cal)

        let streak = StreakCalculator.streak(schedule: .daily, completedDays: completed,
                                             asOf: today, calendar: cal)
        #expect(streak.current == 10)

        // Every one of those days must read as completed on the heatmap.
        for day in 6...15 {
            let state = StatsCalculator.dayState(schedule: .daily, completedDays: completed,
                                                 on: Cal.day(2025, 1, day, in: cal), asOf: today, calendar: cal)
            #expect(state == .completed)
        }
        // A future day and an earlier missed day round it out.
        #expect(StatsCalculator.dayState(schedule: .daily, completedDays: completed,
                on: Cal.day(2025, 1, 16, in: cal), asOf: today, calendar: cal) == .future)
        #expect(StatsCalculator.dayState(schedule: .daily, completedDays: completed,
                on: Cal.day(2025, 1, 5, in: cal), asOf: today, calendar: cal) == .missed)
    }

    @Test("Times-per-week streaks work with a Sunday-first calendar")
    func weeklyStreakSundayFirst() {
        let cal = Cal.make(firstWeekday: 1) // Sunday-first
        let today = Cal.day(2025, 1, 15, in: cal) // Wed
        let schedule = Schedule(type: .timesPerWeek, timesPerWeek: 3)
        // Sun-first weeks: current Jan12–18, prev Jan5–11, prev2 Dec29–Jan4.
        let completed = Cal.days([
            (2025, 1, 12), (2025, 1, 13), (2025, 1, 14),   // current: 3
            (2025, 1, 5), (2025, 1, 6), (2025, 1, 7),      // prev: 3
            (2024, 12, 29), (2024, 12, 30), (2024, 12, 31) // prev2: 3
        ], in: cal)

        let streak = StreakCalculator.streak(schedule: schedule, completedDays: completed,
                                             asOf: today, calendar: cal)
        #expect(streak.current == 3)
        #expect(streak.unit == .week)
    }

    @Test("Completion rate clamps sensibly for a goal that only has the current week")
    func ratePartialFirstWeek() {
        let cal = Cal.make()
        let today = Cal.day(2025, 1, 15, in: cal)
        let schedule = Schedule(type: .timesPerWeek, timesPerWeek: 3)
        // Only the current week has completions (3/3), and the window starts
        // this week (mimicking the createdAt clamp the detail view applies).
        let completed = Cal.days([(2025, 1, 13), (2025, 1, 14), (2025, 1, 15)], in: cal)
        let from = cal.dateInterval(of: .weekOfYear, for: today)!.start
        let rate = StatsCalculator.completionRate(schedule: schedule, completedDays: completed,
                                                  from: from, to: today, calendar: cal)
        #expect(rate == 1.0) // a perfect current week reads as 100%, not 0%
    }
}
