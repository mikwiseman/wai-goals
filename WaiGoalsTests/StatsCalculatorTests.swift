import Testing
import Foundation
@testable import WaiGoals

@Suite("StatsCalculator")
struct StatsCalculatorTests {
    let cal = Cal.make()
    var today: Date { Cal.day(2025, 1, 15, in: cal) } // Wed

    // MARK: dayState

    @Test("Day state for a daily goal")
    func dailyDayState() {
        let done = Cal.days([(2025,1,13)], in: cal)
        func state(_ d: (Int,Int,Int)) -> DayState {
            StatsCalculator.dayState(schedule: .daily, completedDays: done,
                                     on: Cal.day(d.0, d.1, d.2, in: cal), asOf: today, calendar: cal)
        }
        #expect(state((2025,1,13)) == .completed)
        #expect(state((2025,1,14)) == .missed)       // past, not done
        #expect(state((2025,1,15)) == .todayPending) // today, not done
        #expect(state((2025,1,16)) == .future)
    }

    @Test("Day state for specific-days goal treats off-days as not scheduled")
    func specificDayState() {
        let mwf = Schedule(type: .specificDays, weekdays: [.monday, .wednesday, .friday])
        let done = Cal.days([(2025,1,13)], in: cal)
        // Tue 14 is not scheduled and not done → notScheduled
        #expect(StatsCalculator.dayState(schedule: mwf, completedDays: done,
                on: Cal.day(2025,1,14, in: cal), asOf: today, calendar: cal) == .notScheduled)
        // Mon 13 scheduled & done → completed
        #expect(StatsCalculator.dayState(schedule: mwf, completedDays: done,
                on: Cal.day(2025,1,13, in: cal), asOf: today, calendar: cal) == .completed)
    }

    // MARK: completionRate

    @Test("Completion rate counts a done today but ignores an undone today")
    func completionRate() {
        let from = Cal.day(2025, 1, 11, in: cal)
        // done 11,13,15 (today done) of scheduled 11..15 → 3/5
        let rate1 = StatsCalculator.completionRate(
            schedule: .daily, completedDays: Cal.days([(2025,1,11),(2025,1,13),(2025,1,15)], in: cal),
            from: from, to: today, calendar: cal)
        #expect(abs(rate1 - 0.6) < 1e-9)

        // today (15) undone → denominator excludes it → 2/4
        let rate2 = StatsCalculator.completionRate(
            schedule: .daily, completedDays: Cal.days([(2025,1,11),(2025,1,13)], in: cal),
            from: from, to: today, calendar: cal)
        #expect(abs(rate2 - 0.5) < 1e-9)
    }

    @Test("Completion rate is zero with no scheduled days due")
    func completionRateEmpty() {
        let rate = StatsCalculator.completionRate(
            schedule: .daily, completedDays: [], from: today, to: today, calendar: cal)
        #expect(rate == 0)
    }

    // MARK: currentWeekProgress

    @Test("Current week progress for a daily goal")
    func weekProgressDaily() {
        // Week Mon13–Sun19, today Wed15 → due 13,14,15 (3). Done 13,15 → 2/3.
        let p = StatsCalculator.currentWeekProgress(
            schedule: .daily, completedDays: Cal.days([(2025,1,13),(2025,1,15)], in: cal),
            asOf: today, calendar: cal)
        #expect(p.done == 2)
        #expect(p.total == 3)
        #expect(!p.isComplete)
    }

    @Test("Current week progress for a times-per-week goal")
    func weekProgressWeekly() {
        let s = Schedule(type: .timesPerWeek, timesPerWeek: 3)
        let p = StatsCalculator.currentWeekProgress(
            schedule: s, completedDays: Cal.days([(2025,1,13),(2025,1,14)], in: cal),
            asOf: today, calendar: cal)
        #expect(p.done == 2)
        #expect(p.total == 3)
    }

    // MARK: weeklyTrend

    @Test("Weekly trend returns the requested number of ordered weeks")
    func weeklyTrend() {
        let points = StatsCalculator.weeklyTrend(
            schedule: .daily, completedDays: Cal.days([(2025,1,13),(2025,1,15)], in: cal),
            weeks: 12, asOf: today, calendar: cal)
        #expect(points.count == 12)
        // Strictly increasing week starts, last is the current week.
        for i in 1..<points.count {
            #expect(points[i].weekStart > points[i - 1].weekStart)
        }
        let currentWeekStart = cal.dateInterval(of: .weekOfYear, for: today)!.start
        #expect(points.last?.weekStart == currentWeekStart)
        for p in points { #expect(p.rate >= 0 && p.rate <= 1) }
    }
}
