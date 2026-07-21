import Foundation
import SwiftData
import Testing
import UIKit
@testable import WaiGoals

@Suite("Achievement engine")
struct AchievementEngineTests {
    private let calendar = Cal.make()

    @Test("The archive has eight distinct generated artifacts")
    @MainActor
    func catalogIsComplete() {
        let ids = AchievementID.allCases.map(\.rawValue)
        let assets = AchievementID.allCases.map(\.assetName)

        #expect(AchievementID.allCases.count == 8)
        #expect(Set(ids).count == ids.count)
        #expect(Set(assets).count == assets.count)
        #expect(assets.allSatisfy { $0.hasPrefix("Achievement") })
        for asset in assets {
            #expect(UIImage(named: asset) != nil)
        }
    }

    @Test("Progress is derived from real check-ins and the best schedule-aware streak")
    func checkInAndStreakProgress() {
        let days = Cal.days((1...14).map { (2025, 1, $0) }, in: calendar)
        let snapshot = AchievementSnapshot(goals: [
            goal(schedule: .daily, emotion: .focus, completions: days)
        ])

        let progress = AchievementEngine.progress(
            in: snapshot,
            asOf: Cal.day(2025, 1, 14, in: calendar),
            calendar: calendar
        )

        #expect(progress[.firstStep]?.isUnlocked == true)
        #expect(progress[.sevenfoldLoop]?.isUnlocked == true)
        #expect(progress[.hiddenLanding]?.isUnlocked == true)
        #expect(progress[.thirtyTurns]?.currentValue == 14)
        #expect(progress[.atlasMaker]?.currentValue == 14)
    }

    @Test("Golden Thread counts only intentions completed on the same local day")
    func intentionKeptProgress() {
        let completed = Cal.days([
            (2025, 1, 2), (2025, 1, 3), (2025, 1, 4), (2025, 1, 5)
        ], in: calendar)
        let intended = Cal.days([
            (2025, 1, 1), (2025, 1, 2), (2025, 1, 3), (2025, 1, 4)
        ], in: calendar)
        let snapshot = AchievementSnapshot(goals: [
            goal(schedule: .daily, emotion: .balance,
                 completions: completed, intentions: intended)
        ])

        let result = AchievementEngine.progress(
            in: snapshot,
            asOf: Cal.day(2025, 1, 5, in: calendar),
            calendar: calendar
        )[.goldenThread]

        #expect(result?.currentValue == 3)
        #expect(result?.isUnlocked == true)
    }

    @Test("Returning Stair unlocks after a missed required step and a real return")
    func dailyComeback() {
        let completed = Cal.days([
            (2025, 1, 1), (2025, 1, 2),
            (2025, 1, 4)
        ], in: calendar)
        let snapshot = AchievementSnapshot(goals: [
            goal(schedule: .daily, emotion: .courage,
                 createdAt: Cal.day(2025, 1, 1, in: calendar),
                 completions: completed)
        ])

        let result = AchievementEngine.progress(
            in: snapshot,
            asOf: Cal.day(2025, 1, 4, in: calendar),
            calendar: calendar
        )[.returningStair]

        #expect(result?.isUnlocked == true)
    }

    @Test("Unscheduled gaps never masquerade as a comeback")
    func scheduledGapIsNotAMiss() {
        let schedule = Schedule(type: .specificDays, weekdays: [.monday, .wednesday, .friday])
        let completed = Cal.days([
            (2025, 1, 6),  // Monday
            (2025, 1, 8)   // Wednesday
        ], in: calendar)
        let snapshot = AchievementSnapshot(goals: [
            goal(schedule: schedule, emotion: .calm,
                 createdAt: Cal.day(2025, 1, 6, in: calendar),
                 completions: completed)
        ])

        let result = AchievementEngine.progress(
            in: snapshot,
            asOf: Cal.day(2025, 1, 8, in: calendar),
            calendar: calendar
        )[.returningStair]

        #expect(result?.isUnlocked == false)
    }

    @Test("A weekly target can recover after a missed full week")
    func weeklyComeback() {
        let schedule = Schedule(type: .timesPerWeek, timesPerWeek: 2)
        let completed = Cal.days([
            (2025, 1, 6), (2025, 1, 7),   // satisfied week
            (2025, 1, 13),                 // missed target
            (2025, 1, 20), (2025, 1, 21)  // satisfied again
        ], in: calendar)
        let snapshot = AchievementSnapshot(goals: [
            goal(schedule: schedule, emotion: .energy,
                 createdAt: Cal.day(2025, 1, 6, in: calendar),
                 completions: completed)
        ])

        let result = AchievementEngine.progress(
            in: snapshot,
            asOf: Cal.day(2025, 1, 21, in: calendar),
            calendar: calendar
        )[.returningStair]

        #expect(result?.isUnlocked == true)
    }

    @Test("Whole Atlas requires completed actions in every emotional world")
    func wholeAtlasProgress() {
        let day = Cal.day(2025, 1, 2, in: calendar)
        let sevenWorlds = Array(GoalEmotion.allCases.dropLast()).map {
            goal(schedule: .daily, emotion: $0, completions: [day])
        }
        let partial = AchievementEngine.progress(
            in: AchievementSnapshot(goals: sevenWorlds),
            asOf: day,
            calendar: calendar
        )[.wholeAtlas]

        let complete = AchievementEngine.progress(
            in: AchievementSnapshot(goals: sevenWorlds + [
                goal(schedule: .daily, emotion: GoalEmotion.allCases.last!, completions: [day])
            ]),
            asOf: day,
            calendar: calendar
        )[.wholeAtlas]

        #expect(partial?.currentValue == 7)
        #expect(partial?.isUnlocked == false)
        #expect(complete?.currentValue == 8)
        #expect(complete?.isUnlocked == true)
    }

    @Test("Only genuinely crossed thresholds become new unlocks")
    func newlyUnlockedDiff() {
        let day = Cal.day(2025, 1, 2, in: calendar)
        let before = AchievementSnapshot(goals: [])
        let after = AchievementSnapshot(goals: [
            goal(schedule: .daily, emotion: .growth, completions: [day])
        ])

        let unlocks = AchievementEngine.newlyUnlocked(
            before: before,
            after: after,
            excluding: [],
            asOf: day,
            calendar: calendar
        )
        let excluded = AchievementEngine.newlyUnlocked(
            before: before,
            after: after,
            excluding: [.firstStep],
            asOf: day,
            calendar: calendar
        )

        #expect(unlocks.map(\.id) == [.firstStep])
        #expect(excluded.isEmpty)
    }

    @Test("A discovered artifact remains owned after later goal edits")
    func durableOwnership() {
        let result = AchievementEngine.progress(
            in: AchievementSnapshot(goals: []),
            unlocked: [.atlasMaker],
            asOf: Cal.day(2025, 1, 2, in: calendar),
            calendar: calendar
        )[.atlasMaker]

        #expect(result?.currentValue == 0)
        #expect(result?.isUnlocked == true)
        #expect(result?.fraction == 1)
        #expect(result?.progressLabel == "Discovered")
    }

    @Test("Reconciliation backfills ownership once without duplicate rewards")
    @MainActor
    func ownershipReconciliationIsIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Goal.self,
            Completion.self,
            Intention.self,
            AchievementUnlock.self,
            configurations: configuration
        )
        let context = container.mainContext
        let day = Cal.day(2025, 1, 2, in: calendar)
        let model = Goal(
            title: "A real goal",
            emotion: .focus,
            schedule: .daily,
            createdAt: Cal.day(2025, 1, 1, in: calendar)
        )
        let completion = Completion(day: day, goal: model)
        model.completions.append(completion)
        context.insert(model)

        AchievementUnlockStore.reconcile(
            goals: [model], context: context, date: day, calendar: calendar
        )
        AchievementUnlockStore.reconcile(
            goals: [model], context: context, date: day, calendar: calendar
        )

        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlock>())
        #expect(unlocks.compactMap(\.achievement) == [.firstStep])
    }

    @Test("Live snapshots exclude archived goals and future history")
    func liveSnapshotFiltersArchivedGoalsAndFutureDates() {
        let past = Cal.day(2025, 1, 2, in: calendar)
        let today = Cal.day(2025, 1, 3, in: calendar)
        let future = Cal.day(2025, 1, 4, in: calendar)
        let active = Goal(
            title: "Active",
            emotion: .focus,
            schedule: .daily,
            createdAt: Cal.day(2025, 1, 1, in: calendar)
        )
        active.completions = [
            Completion(day: calendar.date(byAdding: .hour, value: 18, to: past)!, goal: active),
            Completion(day: today, goal: active),
            Completion(day: future, goal: active)
        ]
        active.intentions = [
            Intention(day: past, goal: active),
            Intention(day: future, goal: active)
        ]

        let archived = Goal(
            title: "Archived",
            emotion: .joy,
            schedule: .daily,
            createdAt: past,
            isArchived: true
        )
        archived.completions = [Completion(day: past, goal: archived)]

        let snapshot = AchievementSnapshot(goals: [active, archived], calendar: calendar)
        let progress = AchievementEngine.progress(
            in: snapshot,
            asOf: today,
            calendar: calendar
        )

        #expect(snapshot.goals.count == 1)
        #expect(progress[.firstStep]?.currentValue == 2)
        #expect(progress[.goldenThread]?.currentValue == 1)
        #expect(progress[.wholeAtlas]?.currentValue == 1)
    }

    @Test("Synthetic completion changes only its target and remains idempotent")
    func addingCompletionTargetsOneGoalAndDeduplicatesDays() {
        let day = Cal.day(2025, 1, 2, in: calendar)
        let firstID = UUID()
        let secondID = UUID()
        let snapshot = AchievementSnapshot(goals: [
            AchievementGoalSnapshot(
                goalID: firstID,
                schedule: .daily,
                emotion: .growth,
                createdAt: Cal.day(2025, 1, 1, in: calendar),
                completionDays: [],
                intentionDays: []
            ),
            AchievementGoalSnapshot(
                goalID: secondID,
                schedule: .daily,
                emotion: .calm,
                createdAt: Cal.day(2025, 1, 1, in: calendar),
                completionDays: [day],
                intentionDays: []
            )
        ])

        let added = snapshot.addingCompletion(
            to: firstID,
            on: calendar.date(byAdding: .hour, value: 20, to: day)!,
            calendar: calendar
        )
        let duplicate = added.addingCompletion(to: firstID, on: day, calendar: calendar)
        let missing = duplicate.addingCompletion(to: UUID(), on: day, calendar: calendar)

        #expect(added.goals[0].completionDays == [day])
        #expect(added.goals[1].completionDays == [day])
        #expect(duplicate == added)
        #expect(missing == duplicate)
    }

    @Test("A thirty-week rhythm unlocks every streak artifact")
    func weeklyStreakBridgesAllAchievementThresholds() {
        let firstWeek = Cal.day(2024, 6, 3, in: calendar)
        let completions = Set((0..<30).compactMap {
            calendar.date(byAdding: .weekOfYear, value: $0, to: firstWeek)
        })
        let lastWeek = completions.max()!
        let snapshot = AchievementSnapshot(goals: [
            goal(
                schedule: Schedule(type: .timesPerWeek, timesPerWeek: 1),
                emotion: .energy,
                createdAt: firstWeek,
                completions: completions
            )
        ])

        let progress = AchievementEngine.progress(
            in: snapshot,
            asOf: lastWeek,
            calendar: calendar
        )

        #expect(progress[.sevenfoldLoop]?.currentValue == 30)
        #expect(progress[.sevenfoldLoop]?.isUnlocked == true)
        #expect(progress[.hiddenLanding]?.isUnlocked == true)
        #expect(progress[.thirtyTurns]?.isUnlocked == true)
    }

    @Test("Simultaneous discoveries retain catalog order")
    func simultaneousUnlocksHaveStableOrder() {
        let days = Cal.days((1...7).map { (2025, 1, $0) }, in: calendar)
        let before = AchievementSnapshot(goals: [])
        let after = AchievementSnapshot(goals: [
            goal(schedule: .daily, emotion: .growth, completions: days)
        ])

        let unlocks = AchievementEngine.newlyUnlocked(
            before: before,
            after: after,
            excluding: [],
            asOf: Cal.day(2025, 1, 7, in: calendar),
            calendar: calendar
        )

        #expect(unlocks.map(\.id) == [.firstStep, .sevenfoldLoop])
    }

    @Test("A return requires a success before the missed daily step")
    func dailyComebackRejectsBoundaryFalsePositives() {
        let asOf = Cal.day(2025, 1, 4, in: calendar)
        let snapshots = [
            goal(
                schedule: .daily,
                emotion: .courage,
                createdAt: Cal.day(2025, 1, 1, in: calendar),
                completions: Cal.days([(2025, 1, 3)], in: calendar)
            ),
            goal(
                schedule: .daily,
                emotion: .courage,
                createdAt: Cal.day(2025, 1, 1, in: calendar),
                completions: Cal.days([(2025, 1, 3), (2025, 1, 4)], in: calendar)
            ),
            goal(
                schedule: .daily,
                emotion: .courage,
                createdAt: Cal.day(2025, 1, 3, in: calendar),
                completions: Cal.days([(2025, 1, 1), (2025, 1, 3), (2025, 1, 4)], in: calendar)
            )
        ]

        for snapshot in snapshots {
            let result = AchievementEngine.progress(
                in: AchievementSnapshot(goals: [snapshot]),
                asOf: asOf,
                calendar: calendar
            )[.returningStair]
            #expect(result?.isUnlocked == false)
        }
    }

    @Test("An unfinished week is not a comeback without a later recovery")
    func weeklyComebackRejectsIncompleteHistories() {
        let schedule = Schedule(type: .timesPerWeek, timesPerWeek: 2)
        let noPriorSuccess = goal(
            schedule: schedule,
            emotion: .balance,
            createdAt: Cal.day(2025, 1, 6, in: calendar),
            completions: Cal.days([
                (2025, 1, 6),
                (2025, 1, 13), (2025, 1, 14)
            ], in: calendar)
        )
        let currentWeekIncomplete = goal(
            schedule: schedule,
            emotion: .balance,
            createdAt: Cal.day(2025, 1, 6, in: calendar),
            completions: Cal.days([
                (2025, 1, 6), (2025, 1, 7),
                (2025, 1, 13)
            ], in: calendar)
        )

        for snapshot in [noPriorSuccess, currentWeekIncomplete] {
            let result = AchievementEngine.progress(
                in: AchievementSnapshot(goals: [snapshot]),
                asOf: Cal.day(2025, 1, 14, in: calendar),
                calendar: calendar
            )[.returningStair]
            #expect(result?.isUnlocked == false)
        }
    }

    @Test("Reconciliation preserves invalid records and fills only missing ownership")
    @MainActor
    func reconciliationHandlesExistingAndInvalidRows() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Goal.self,
            Completion.self,
            Intention.self,
            AchievementUnlock.self,
            configurations: configuration
        )
        let context = container.mainContext
        let firstDay = Cal.day(2025, 1, 1, in: calendar)
        let seventhDay = Cal.day(2025, 1, 7, in: calendar)
        let model = Goal(
            title: "Seven real steps",
            emotion: .focus,
            schedule: .daily,
            createdAt: firstDay
        )
        model.completions = (1...7).map {
            Completion(day: Cal.day(2025, 1, $0, in: calendar), goal: model)
        }
        context.insert(model)
        context.insert(AchievementUnlock(achievement: .firstStep, unlockedAt: firstDay))
        let invalid = AchievementUnlock(achievement: .atlasMaker, unlockedAt: firstDay)
        invalid.achievementRawValue = "retiredArtifact"
        context.insert(invalid)
        context.saveOrLog()

        AchievementUnlockStore.reconcile(
            goals: [model], context: context, date: seventhDay, calendar: calendar
        )
        AchievementUnlockStore.reconcile(
            goals: [model], context: context, date: seventhDay, calendar: calendar
        )

        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlock>())
        #expect(unlocks.count == 3)
        #expect(unlocks.filter { $0.achievementRawValue == AchievementID.firstStep.rawValue }.count == 1)
        #expect(unlocks.filter { $0.achievementRawValue == AchievementID.sevenfoldLoop.rawValue }.count == 1)
        #expect(unlocks.contains { $0.achievementRawValue == "retiredArtifact" && $0.achievement == nil })
    }

    @Test("Recording discoveries is idempotent even when view state is stale")
    @MainActor
    func recordingDiscoveriesIsIdempotent() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Goal.self,
            Completion.self,
            Intention.self,
            AchievementUnlock.self,
            configurations: configuration
        )
        let context = container.mainContext
        let date = Cal.day(2025, 1, 2, in: calendar)

        AchievementUnlockStore.record(
            [.firstStep, .firstStep],
            context: context,
            date: date
        )
        AchievementUnlockStore.record(
            [.firstStep],
            context: context,
            date: date
        )

        let unlocks = try context.fetch(FetchDescriptor<AchievementUnlock>())
        #expect(unlocks.count == 1)
        #expect(unlocks.first?.achievement == .firstStep)
        #expect(unlocks.first?.unlockedAt == date)
    }

    private func goal(
        schedule: Schedule,
        emotion: GoalEmotion?,
        createdAt: Date? = nil,
        completions: Set<Date>,
        intentions: Set<Date> = []
    ) -> AchievementGoalSnapshot {
        AchievementGoalSnapshot(
            goalID: UUID(),
            schedule: schedule,
            emotion: emotion,
            createdAt: createdAt ?? Cal.day(2025, 1, 1, in: calendar),
            completionDays: completions,
            intentionDays: intentions
        )
    }
}
