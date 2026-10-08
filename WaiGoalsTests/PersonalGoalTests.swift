import Testing
import Foundation
@testable import WaiGoals

@MainActor
struct PersonalGoalTests {
    @Test func personalDirectionIsOptionalAndPreserved() {
        let goal = Goal(title: "Read")
        #expect(goal.personalWhy == nil)
        #expect(goal.smallStep == nil)
        goal.personalWhy = "Stay curious"
        goal.smallStep = "One page"
        #expect(goal.nextStepText == "One page")
        #expect(goal.personalWhy == "Stay curious")
    }
    @Test func nextStepUsesTheGoalWhenNoSmallStepExists() {
        let goal = Goal(title: "Walk")
        goal.smallStep = "  "
        #expect(goal.nextStepText == "Walk")
    }
    @Test func snapshotUsesLocalDatesAndIncludesArchivedGoals() throws {
        let goal = Goal(title: "Read", isArchived: true)
        goal.personalWhy = "Curiosity"
        let data = try GoalsSnapshot.make(goals: [goal], deviceId: UUID(), now: Date(timeIntervalSince1970: 1791451800))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let goals = try #require(object["goals"] as? [[String: Any]])
        #expect(goals[0]["why"] as? String == "Curiosity")
        #expect(goals[0]["archived"] as? Bool == true)
        #expect(object["timezone"] as? String == TimeZone.current.identifier)
    }
}
