import Foundation

/// A collectible artifact earned by moving a real goal forward. The catalog is
/// deliberately small: each item represents a different healthy behavior, not
/// another arbitrary counter.
enum AchievementID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case firstStep
    case goldenThread
    case returningStair
    case sevenfoldLoop
    case hiddenLanding
    case thirtyTurns
    case atlasMaker
    case wholeAtlas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstStep: "First Step"
        case .goldenThread: "Golden Thread"
        case .returningStair: "Returning Stair"
        case .sevenfoldLoop: "Sevenfold Loop"
        case .hiddenLanding: "Hidden Landing"
        case .thirtyTurns: "Thirty Turns"
        case .atlasMaker: "Atlas Maker"
        case .wholeAtlas: "Whole Atlas"
        }
    }

    var shortMeaning: String {
        switch self {
        case .firstStep: "The path appeared."
        case .goldenThread: "Intention became action."
        case .returningStair: "You came back."
        case .sevenfoldLoop: "A rhythm can hold you."
        case .hiddenLanding: "Consistency revealed more."
        case .thirtyTurns: "The path became part of you."
        case .atlasMaker: "A hundred real steps."
        case .wholeAtlas: "Every inner world moved."
        }
    }

    var requirement: String {
        switch self {
        case .firstStep: "Complete your first step."
        case .goldenThread: "Approve an intention and keep it 3 times."
        case .returningStair: "Return after a missed scheduled step."
        case .sevenfoldLoop: "Reach a 7-day or 7-week streak."
        case .hiddenLanding: "Reach a 14-day or 14-week streak."
        case .thirtyTurns: "Reach a 30-day or 30-week streak."
        case .atlasMaker: "Complete 100 steps across your goals."
        case .wholeAtlas: "Complete a step in all 8 emotional worlds."
        }
    }

    var assetName: String {
        switch self {
        case .firstStep: "AchievementFirstStep"
        case .goldenThread: "AchievementGoldenThread"
        case .returningStair: "AchievementReturningStair"
        case .sevenfoldLoop: "AchievementSevenfoldLoop"
        case .hiddenLanding: "AchievementHiddenLanding"
        case .thirtyTurns: "AchievementThirtyTurns"
        case .atlasMaker: "AchievementAtlasMaker"
        case .wholeAtlas: "AchievementWholeAtlas"
        }
    }

    fileprivate var targetValue: Int {
        switch self {
        case .firstStep, .returningStair: 1
        case .goldenThread: 3
        case .sevenfoldLoop: 7
        case .hiddenLanding: 14
        case .thirtyTurns: 30
        case .atlasMaker: 100
        case .wholeAtlas: GoalEmotion.allCases.count
        }
    }
}

struct AchievementGoalSnapshot: Sendable, Equatable {
    let goalID: UUID
    let schedule: Schedule
    let emotion: GoalEmotion?
    let createdAt: Date
    let completionDays: Set<Date>
    let intentionDays: Set<Date>
}

struct AchievementSnapshot: Sendable, Equatable {
    let goals: [AchievementGoalSnapshot]

    init(goals: [AchievementGoalSnapshot]) {
        self.goals = goals
    }

    init(goals: [Goal], calendar: Calendar = .current) {
        self.goals = goals.filter { !$0.isArchived }.map { goal in
            AchievementGoalSnapshot(
                goalID: goal.id,
                schedule: goal.schedule,
                emotion: goal.emotion,
                createdAt: goal.createdAt,
                completionDays: goal.completedDays(calendar: calendar),
                intentionDays: Set(goal.intentions.map { calendar.startOfDay(for: $0.day) })
            )
        }
    }

    func addingCompletion(
        to goalID: UUID,
        on date: Date,
        calendar: Calendar = .current
    ) -> AchievementSnapshot {
        let day = calendar.startOfDay(for: date)
        return AchievementSnapshot(goals: goals.map { goal in
            guard goal.goalID == goalID else { return goal }
            var days = goal.completionDays
            days.insert(day)
            return AchievementGoalSnapshot(
                goalID: goal.goalID,
                schedule: goal.schedule,
                emotion: goal.emotion,
                createdAt: goal.createdAt,
                completionDays: days,
                intentionDays: goal.intentionDays
            )
        })
    }
}

struct AchievementProgress: Identifiable, Equatable, Hashable, Sendable {
    let id: AchievementID
    let currentValue: Int
    let targetValue: Int
    var wasPreviouslyUnlocked = false

    var isUnlocked: Bool { wasPreviouslyUnlocked || currentValue >= targetValue }
    var fraction: Double {
        if isUnlocked { return 1 }
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1)
    }

    var progressLabel: String {
        if isUnlocked { return "Discovered" }
        return switch id {
        case .firstStep: "\(currentValue) of \(targetValue) steps"
        case .goldenThread: "\(currentValue) of \(targetValue) promises kept"
        case .returningStair: "A return is waiting"
        case .sevenfoldLoop, .hiddenLanding, .thirtyTurns:
            "\(currentValue) of \(targetValue) streak periods"
        case .atlasMaker: "\(currentValue) of \(targetValue) steps"
        case .wholeAtlas: "\(currentValue) of \(targetValue) worlds"
        }
    }
}

enum AchievementEngine {
    static func progress(
        in snapshot: AchievementSnapshot,
        unlocked: Set<AchievementID> = [],
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> [AchievementID: AchievementProgress] {
        let today = calendar.startOfDay(for: date)
        let normalized = snapshot.goals.map { goal in
            AchievementGoalSnapshot(
                goalID: goal.goalID,
                schedule: goal.schedule,
                emotion: goal.emotion,
                createdAt: calendar.startOfDay(for: goal.createdAt),
                completionDays: Set(goal.completionDays.map { calendar.startOfDay(for: $0) }.filter { $0 <= today }),
                intentionDays: Set(goal.intentionDays.map { calendar.startOfDay(for: $0) }.filter { $0 <= today })
            )
        }

        let totalSteps = normalized.reduce(0) { $0 + $1.completionDays.count }
        let promisesKept = normalized.reduce(0) { result, goal in
            result + goal.completionDays.intersection(goal.intentionDays).count
        }
        let bestStreak = normalized.map { goal in
            StreakCalculator.streak(
                schedule: goal.schedule,
                completedDays: goal.completionDays,
                asOf: today,
                calendar: calendar
            ).best
        }.max() ?? 0
        let completedWorlds = Set(normalized.compactMap { goal -> GoalEmotion? in
            guard !goal.completionDays.isEmpty else { return nil }
            return goal.emotion
        }).count
        let hasReturn = normalized.contains {
            containsComeback(in: $0, asOf: today, calendar: calendar)
        }

        let values: [AchievementID: Int] = [
            .firstStep: totalSteps,
            .goldenThread: promisesKept,
            .returningStair: hasReturn ? 1 : 0,
            .sevenfoldLoop: bestStreak,
            .hiddenLanding: bestStreak,
            .thirtyTurns: bestStreak,
            .atlasMaker: totalSteps,
            .wholeAtlas: completedWorlds
        ]

        return Dictionary(uniqueKeysWithValues: AchievementID.allCases.map { id in
            (id, AchievementProgress(
                id: id,
                currentValue: values[id, default: 0],
                targetValue: id.targetValue,
                wasPreviouslyUnlocked: unlocked.contains(id)
            ))
        })
    }

    static func newlyUnlocked(
        before: AchievementSnapshot,
        after: AchievementSnapshot,
        excluding alreadyCelebrated: Set<AchievementID>,
        asOf date: Date = .now,
        calendar: Calendar = .current
    ) -> [AchievementProgress] {
        let old = progress(in: before, asOf: date, calendar: calendar)
        let new = progress(in: after, asOf: date, calendar: calendar)

        return AchievementID.allCases.compactMap { id in
            guard !alreadyCelebrated.contains(id),
                  old[id]?.isUnlocked != true,
                  let value = new[id], value.isUnlocked
            else { return nil }
            return value
        }
    }

    private static func containsComeback(
        in goal: AchievementGoalSnapshot,
        asOf today: Date,
        calendar: Calendar
    ) -> Bool {
        switch goal.schedule.type {
        case .daily, .specificDays:
            return containsDayComeback(in: goal, calendar: calendar)
        case .timesPerWeek:
            return containsWeekComeback(in: goal, asOf: today, calendar: calendar)
        }
    }

    private static func containsDayComeback(
        in goal: AchievementGoalSnapshot,
        calendar: Calendar
    ) -> Bool {
        let days = goal.completionDays
            .filter { $0 >= goal.createdAt }
            .sorted()
        guard days.count >= 2 else { return false }

        for pair in zip(days, days.dropFirst()) {
            var cursor = calendar.date(byAdding: .day, value: 1, to: pair.0)
            while let day = cursor, day < pair.1 {
                if goal.schedule.isScheduled(on: day, calendar: calendar),
                   !goal.completionDays.contains(day) {
                    return true
                }
                cursor = calendar.date(byAdding: .day, value: 1, to: day)
            }
        }
        return false
    }

    private static func containsWeekComeback(
        in goal: AchievementGoalSnapshot,
        asOf today: Date,
        calendar: Calendar
    ) -> Bool {
        guard let createdWeek = calendar.dateInterval(of: .weekOfYear, for: goal.createdAt)?.start,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let lastCompletion = goal.completionDays.max(),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastCompletion)?.start
        else { return false }

        var counts: [Date: Int] = [:]
        for day in goal.completionDays {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            counts[week, default: 0] += 1
        }

        var hasSatisfiedWeek = false
        var missedAfterSuccess = false
        var week = createdWeek
        while week <= min(lastWeek, currentWeek) {
            let satisfied = counts[week, default: 0] >= goal.schedule.timesPerWeek
            if satisfied {
                if hasSatisfiedWeek, missedAfterSuccess { return true }
                hasSatisfiedWeek = true
            } else if hasSatisfiedWeek, week < currentWeek {
                missedAfterSuccess = true
            }

            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return false
    }
}
