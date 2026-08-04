import Testing
import Foundation
import SwiftData
@testable import WaiGoals

/// Retroactive completion ("I did it yesterday") — the detail view's week strip
/// and history heatmap toggle completions for arbitrary past days.
@Suite("Backdated completions")
@MainActor
struct BackdateCompletionTests {
    let cal = Cal.make()

    @Test("Marking a past day inserts a completion normalized to that day")
    func markPastDay() throws {
        let context = try makeContext()
        let goal = Goal(title: "Meditate")
        context.insert(goal)

        let yesterday = Cal.day(2025, 1, 14, in: cal) // Tue
        let today = Cal.day(2025, 1, 15, in: cal) // Wed

        let streak = goal.toggleCompletion(on: yesterday, context: context, calendar: cal)

        #expect(streak == 1)
        #expect(goal.isCompleted(on: yesterday, calendar: cal))
        #expect(!goal.isCompleted(on: today, calendar: cal))
        #expect(goal.completions.count == 1)
        #expect(goal.completions.first?.day == cal.startOfDay(for: yesterday))
    }

    @Test("Toggling the same past day again removes its completion")
    func unmarkPastDay() throws {
        let context = try makeContext()
        let goal = Goal(title: "Meditate")
        context.insert(goal)

        let yesterday = Cal.day(2025, 1, 14, in: cal)
        _ = goal.toggleCompletion(on: yesterday, context: context, calendar: cal)
        let result = goal.toggleCompletion(on: yesterday, context: context, calendar: cal)

        #expect(result == nil) // removal returns no streak
        #expect(!goal.isCompleted(on: yesterday, calendar: cal))
        #expect(goal.completions.isEmpty)
    }

    @Test("Backdating yesterday extends today's streak")
    func backdateRepairsStreak() throws {
        let context = try makeContext()
        let goal = Goal(title: "Read 20 pages") // daily by default
        context.insert(goal)

        let today = Cal.day(2025, 1, 15, in: cal)
        let yesterday = Cal.day(2025, 1, 14, in: cal)
        _ = goal.toggleCompletion(on: today, context: context, calendar: cal)
        #expect(goal.streak(asOf: today, calendar: cal).current == 1)

        _ = goal.toggleCompletion(on: yesterday, context: context, calendar: cal)
        #expect(goal.streak(asOf: today, calendar: cal).current == 2)
    }

    @Test("The heatmap shows a backdated completion even on an unscheduled day")
    func unscheduledDayBackdate() throws {
        let context = try makeContext()
        // Mondays only; the user still did it on a Tuesday and marks it.
        let goal = Goal(title: "Gym", schedule: Schedule(type: .specificDays, weekdays: [.monday]))
        context.insert(goal)

        let tuesday = Cal.day(2025, 1, 14, in: cal)
        let today = Cal.day(2025, 1, 15, in: cal)
        _ = goal.toggleCompletion(on: tuesday, context: context, calendar: cal)

        let state = StatsCalculator.dayState(
            schedule: goal.schedule,
            completedDays: goal.completedDays(calendar: cal),
            on: tuesday, asOf: today, calendar: cal
        )
        #expect(state == .completed)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Goal.self, Completion.self, Intention.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
