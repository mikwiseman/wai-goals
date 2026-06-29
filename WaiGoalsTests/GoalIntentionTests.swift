import Testing
import Foundation
import SwiftData
@testable import WaiGoals

@Suite("Goal intentions")
@MainActor
struct GoalIntentionTests {
    let cal = Cal.make()

    @Test("Approving an intention creates one record per local day and updates its cue")
    func approveCreatesDailyRecordAndUpdatesCue() throws {
        let context = try makeContext()
        let goal = Goal(title: "Read 20 pages")
        context.insert(goal)

        let today = Cal.day(2025, 1, 15, in: cal)
        let tomorrow = Cal.day(2025, 1, 16, in: cal)

        #expect(!goal.hasIntention(on: today, calendar: cal))

        let first = goal.approveIntention(on: today, cue: .evening, context: context, calendar: cal)
        #expect(first.cue == .evening)
        #expect(goal.hasIntention(on: today, calendar: cal))
        #expect(!goal.hasIntention(on: tomorrow, calendar: cal))
        #expect(goal.intentions.count == 1)

        let updated = goal.approveIntention(on: today, cue: .beforeBed, context: context, calendar: cal)
        #expect(updated.id == first.id)
        #expect(updated.cue == .beforeBed)
        #expect(goal.intentions.count == 1)
    }

    @Test("Intending today does not mark the goal complete")
    func intentionDoesNotCompleteGoal() throws {
        let context = try makeContext()
        let goal = Goal(title: "Stop working at 7 PM")
        context.insert(goal)

        let today = Cal.day(2025, 1, 15, in: cal)
        _ = goal.approveIntention(on: today, cue: .evening, context: context, calendar: cal)

        #expect(goal.hasIntention(on: today, calendar: cal))
        #expect(!goal.isCompleted(on: today, calendar: cal))
        #expect(goal.completions.isEmpty)
    }

    @Test("Completing a goal preserves the approved intention")
    func completionPreservesIntention() throws {
        let context = try makeContext()
        let goal = Goal(title: "Post in Telegram")
        context.insert(goal)

        let today = Cal.day(2025, 1, 15, in: cal)
        _ = goal.approveIntention(on: today, cue: .firstBreak, context: context, calendar: cal)

        let streak = goal.toggleCompletion(on: today, context: context, calendar: cal)

        #expect(streak == 1)
        #expect(goal.isCompleted(on: today, calendar: cal))
        #expect(goal.hasIntention(on: today, calendar: cal))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Goal.self, Completion.self, Intention.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }
}
