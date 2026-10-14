import Foundation
import SwiftData
import Testing
@testable import WaiGoals

@MainActor
struct GoalsFullSyncTests {
    private func container(url: URL? = nil) throws -> ModelContainer {
        let config = url.map { ModelConfiguration(url: $0) } ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Goal.self, Completion.self, Intention.self, JournalEntry.self,
                                  AchievementUnlock.self, GoalsSyncMetadata.self, configurations: config)
    }
    @Test func fullRoundTripRetainsSettingsAndOldHistory() throws {
        let source = try container(), destination = try container()
        let c = Cal.make()
        let goal = Goal(title: "Read", symbol: "book", schedule: .daily, reminderEnabled: true,
                        reminderTime: Cal.day(2020, 1, 1, in: c), sortIndex: 9)
        goal.personalWhy = "Curiosity"; goal.smallStep = "One page"
        source.mainContext.insert(goal)
        let completion = Completion(day: Cal.day(2020, 3, 8, in: c), goal: goal)
        source.mainContext.insert(completion)
        source.mainContext.insert(Intention(day: Cal.day(2020, 3, 9, in: c), goal: goal))
        let journal = JournalEntry(kind: .dayReview, date: Cal.day(2020, 3, 8, in: c), text: "Old history", calendar: c)
        journal.insight = "Keep this"; source.mainContext.insert(journal)
        try source.mainContext.save()
        let original = try GoalsSyncDocument.capture(source.mainContext, calendar: c)
        try original.apply(to: destination.mainContext, calendar: c)
        try destination.mainContext.save()
        #expect(try GoalsSyncDocument.capture(destination.mainContext, calendar: c) == original)
        #expect(original[.completions][completion.id.uuidString.lowercased()]?["day"] == .string("2020-03-08"))
        let travel = try GoalsSyncDocument.capture(source.mainContext, calendar: Cal.make(timeZone: "Pacific/Honolulu"))
        #expect(travel[.completions] == original[.completions])
    }
    @Test func concurrentFieldsMergeButSameFieldNeedsChoice() throws {
        let source = try container(), g = Goal(title: "Before")
        source.mainContext.insert(g)
        let base = try GoalsSyncDocument.capture(source.mainContext)
        let id = g.id.uuidString.lowercased()
        var local = base, remote = base
        local[.goals][id]?["title"] = .string("Local")
        remote[.goals][id]?["smallStep"] = .string("Remote step")
        let merged = try GoalsSyncDocument.merge(base: base, local: local, remote: remote)
        #expect(merged[.goals][id]?["title"] == .string("Local"))
        #expect(merged[.goals][id]?["smallStep"] == .string("Remote step"))
        remote[.goals][id]?["title"] = .string("Remote")
        #expect(throws: GoalsSyncConflict.self) { try GoalsSyncDocument.merge(base: base, local: local, remote: remote) }
        let chosen = try GoalsSyncDocument.merge(base: base, local: local, remote: remote, preferLocal: true)
        #expect(chosen[.goals][id]?["title"] == .string("Local"))
        #expect(chosen[.goals][id]?["smallStep"] == .string("Remote step"))
    }
    @Test func pendingRequestSurvivesRestartAndEditsDuringFlight() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("goals.store"), deviceID = UUID()
        let operationID: String
        do {
            let store = try container(url: url)
            store.mainContext.insert(Goal(title: "Before"))
            let session = try GoalsSyncSession(context: store.mainContext, accountID: "qa", deviceID: deviceID)
            operationID = try session.prepare().request.operationId
        }
        let store = try container(url: url)
        let session = try GoalsSyncSession(context: store.mainContext, accountID: "qa", deviceID: deviceID)
        let pending = try session.prepare()
        #expect(pending.request.operationId == operationID)
        let goal = try #require(store.mainContext.fetch(FetchDescriptor<Goal>()).first)
        goal.smallStep = "Edited while offline"
        try store.mainContext.save()
        var remote = pending.local
        remote[.goals][goal.id.uuidString.lowercased()]?["title"] = .string("From chat")
        try session.accept(GoalsSyncResponse(revision: 1, state: remote), pending: pending)
        #expect(goal.title == "From chat")
        #expect(goal.smallStep == "Edited while offline")
        let next = try session.prepare()
        #expect(next.request.operationId != operationID)
        #expect(next.request.changes.count == 1)
        #expect(next.request.changes[0].after?["smallStep"] == .string("Edited while offline"))
    }
}
