import Testing
import Foundation
@testable import WaiGoals

/// Reference "today" across these tests: Wed 2025-01-15.
/// Jan 2025 weekdays — Mon: 6,13 · Tue: 7,14 · Wed: 8,15 · Thu: 9 · Fri: 10,17 · weekend: 11,12,18,19
@Suite("StreakCalculator")
struct StreakCalculatorTests {
    let cal = Cal.make()
    var today: Date { Cal.day(2025, 1, 15, in: cal) }

    func streak(_ schedule: Schedule, _ tuples: [(Int, Int, Int)]) -> StreakResult {
        StreakCalculator.streak(schedule: schedule, completedDays: Cal.days(tuples, in: cal),
                                asOf: today, calendar: cal)
    }

    // MARK: Daily

    @Test("Daily: five consecutive days")
    func dailyFive() {
        let r = streak(.daily, [(2025,1,11),(2025,1,12),(2025,1,13),(2025,1,14),(2025,1,15)])
        #expect(r.current == 5)
        #expect(r.best == 5)
        #expect(r.unit == .day)
    }

    @Test("Daily: today undone is grace, not a break")
    func dailyGraceToday() {
        let r = streak(.daily, [(2025,1,11),(2025,1,12),(2025,1,13),(2025,1,14)])
        #expect(r.current == 4) // today (15) pending, streak holds at 4
        #expect(r.best == 4)
    }

    @Test("Daily: a missed past day breaks the current streak but not the best")
    func dailyGap() {
        // missed Jan 13
        let r = streak(.daily, [(2025,1,10),(2025,1,11),(2025,1,12),(2025,1,14),(2025,1,15)])
        #expect(r.current == 2) // 14,15
        #expect(r.best == 3)    // 10,11,12
    }

    @Test("Daily: empty history")
    func dailyEmpty() {
        let r = streak(.daily, [])
        #expect(r.current == 0)
        #expect(r.best == 0)
    }

    @Test("Daily: only today")
    func dailyOnlyToday() {
        let r = streak(.daily, [(2025,1,15)])
        #expect(r.current == 1)
        #expect(r.best == 1)
    }

    // MARK: Specific days (Mon/Wed/Fri) — unscheduled days must never break a streak

    var mwf: Schedule { Schedule(type: .specificDays, weekdays: [.monday, .wednesday, .friday]) }

    @Test("Specific days: consecutive scheduled days, ignoring gaps between them")
    func specificConsecutive() {
        // Mon6, Wed8, Fri10, Mon13, Wed15 — all scheduled, all done
        let r = streak(mwf, [(2025,1,6),(2025,1,8),(2025,1,10),(2025,1,13),(2025,1,15)])
        #expect(r.current == 5)
        #expect(r.best == 5)
        #expect(r.unit == .day)
    }

    @Test("Specific days: missing a scheduled day breaks it")
    func specificMiss() {
        // missed Mon13
        let r = streak(mwf, [(2025,1,6),(2025,1,8),(2025,1,10),(2025,1,15)])
        #expect(r.current == 1) // Wed15 only
        #expect(r.best == 3)    // Mon6, Wed8, Fri10
    }

    @Test("Specific days: today scheduled but undone is grace")
    func specificGraceToday() {
        // Wed15 (today, scheduled) not done; prior scheduled all done
        let r = streak(mwf, [(2025,1,6),(2025,1,8),(2025,1,10),(2025,1,13)])
        #expect(r.current == 4)
        #expect(r.best == 4)
    }

    // MARK: Times per week (target 3, Monday-first weeks)
    // Weeks: current = Jan13–19 · prev = Jan6–12 · prev2 = Dec30–Jan5

    var thrice: Schedule { Schedule(type: .timesPerWeek, timesPerWeek: 3) }

    @Test("Times per week: three satisfied weeks in a row")
    func weeklyThree() {
        let r = streak(thrice, [
            (2025,1,13),(2025,1,14),(2025,1,15),     // current week: 3
            (2025,1,6),(2025,1,7),(2025,1,8),        // prev: 3
            (2024,12,30),(2024,12,31),(2025,1,2)     // prev2: 3
        ])
        #expect(r.current == 3)
        #expect(r.best == 3)
        #expect(r.unit == .week)
    }

    @Test("Times per week: current week below target is grace")
    func weeklyGrace() {
        let r = streak(thrice, [
            (2025,1,13),(2025,1,14),                 // current week: 2 (< 3) → grace
            (2025,1,6),(2025,1,7),(2025,1,8),        // prev: 3
            (2024,12,30),(2024,12,31),(2025,1,2)     // prev2: 3
        ])
        #expect(r.current == 2) // two satisfied prior weeks
        #expect(r.best == 2)
    }

    @Test("Times per week: a missed past week breaks the streak")
    func weeklyBreak() {
        let r = streak(thrice, [
            (2025,1,13),(2025,1,14),(2025,1,15),     // current: 3
            (2025,1,6),                              // prev: 1 (< 3) → break
            (2024,12,30),(2024,12,31),(2025,1,2)     // prev2: 3
        ])
        #expect(r.current == 1) // only the current week
        #expect(r.best == 1)
    }

    // MARK: Invariant

    @Test("Best is always at least the current streak")
    func invariantBestGECurrent() {
        let samples: [[(Int,Int,Int)]] = [
            [(2025,1,15)],
            [(2025,1,11),(2025,1,12),(2025,1,13),(2025,1,14),(2025,1,15)],
            [(2025,1,10),(2025,1,11),(2025,1,12),(2025,1,14),(2025,1,15)]
        ]
        for s in samples {
            let r = streak(.daily, s)
            #expect(r.best >= r.current)
        }
    }
}
