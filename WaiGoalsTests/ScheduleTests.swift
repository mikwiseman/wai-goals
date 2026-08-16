import Testing
import Foundation
@testable import WaiGoals

@Suite("Schedule")
struct ScheduleTests {
    let cal = Cal.make()

    @Test("Daily is always scheduled")
    func daily() {
        let s = Schedule.daily
        #expect(s.isScheduled(on: Cal.day(2025, 1, 15, in: cal), calendar: cal))
        #expect(s.isScheduled(on: Cal.day(2025, 1, 18, in: cal), calendar: cal))
        #expect(s.streakUnit == .day)
    }

    @Test("Specific days only on chosen weekdays")
    func specificDays() {
        // Mon/Wed/Fri. Jan 13 2025 = Mon, 14 = Tue, 15 = Wed.
        let s = Schedule(type: .specificDays, weekdays: [.monday, .wednesday, .friday])
        #expect(s.isScheduled(on: Cal.day(2025, 1, 13, in: cal), calendar: cal))   // Mon
        #expect(!s.isScheduled(on: Cal.day(2025, 1, 14, in: cal), calendar: cal))  // Tue
        #expect(s.isScheduled(on: Cal.day(2025, 1, 15, in: cal), calendar: cal))   // Wed
        #expect(s.streakUnit == .day)
    }

    @Test("Times-per-week is actionable any day and uses week streaks")
    func timesPerWeek() {
        let s = Schedule(type: .timesPerWeek, timesPerWeek: 3)
        #expect(s.isScheduled(on: Cal.day(2025, 1, 14, in: cal), calendar: cal))
        #expect(s.streakUnit == .week)
    }

    @Test("Times-per-week target is clamped to 1...7")
    func clamping() {
        #expect(Schedule(type: .timesPerWeek, timesPerWeek: 0).timesPerWeek == 1)
        #expect(Schedule(type: .timesPerWeek, timesPerWeek: 99).timesPerWeek == 7)
    }

    @Test("Workdays is scheduled every day except Saturday")
    func workdays() {
        let s = Schedule.workdays
        // Jan 13 2025 = Mon, 17 = Fri, 18 = Sat, 19 = Sun.
        #expect(s.type == .specificDays)
        #expect(s.isScheduled(on: Cal.day(2025, 1, 13, in: cal), calendar: cal))   // Mon
        #expect(s.isScheduled(on: Cal.day(2025, 1, 17, in: cal), calendar: cal))   // Fri
        #expect(!s.isScheduled(on: Cal.day(2025, 1, 18, in: cal), calendar: cal))  // Sat
        #expect(s.isScheduled(on: Cal.day(2025, 1, 19, in: cal), calendar: cal))   // Sun
        #expect(s.streakUnit == .day)
    }

    @Test("Summaries read naturally")
    func summaries() {
        #expect(Schedule.daily.summary(calendar: cal) == "Daily")
        #expect(Schedule(type: .timesPerWeek, timesPerWeek: 3).summary(calendar: cal) == "3× / week")
        #expect(Schedule(type: .specificDays, weekdays: Set(Weekday.allCases)).summary(calendar: cal) == "Daily")
        #expect(Schedule.workdays.summary(calendar: cal) == "Workdays")
    }
}
