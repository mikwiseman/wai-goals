import Foundation
import SwiftData

/// Persists ownership after an artifact has been earned from real goal history.
/// Progress is still derived from that history; the record only prevents a
/// legitimately discovered artifact from disappearing after later edits.
@Model
final class AchievementUnlock {
    @Attribute(.unique) var achievementRawValue: String = ""
    var unlockedAt: Date = Date.now

    init(achievement: AchievementID, unlockedAt: Date = .now) {
        self.achievementRawValue = achievement.rawValue
        self.unlockedAt = unlockedAt
    }

    var achievement: AchievementID? {
        AchievementID(rawValue: achievementRawValue)
    }
}

enum AchievementUnlockStore {
    /// Records newly discovered artifacts without relying on a possibly stale
    /// SwiftUI query. The unique persisted ID remains the final integrity guard.
    @MainActor
    static func record(
        _ achievements: [AchievementID],
        context: ModelContext,
        date: Date = .now
    ) {
        let existing = Set(context.allAchievementUnlocks().compactMap(\.achievement))
        let missing = Set(achievements).subtracting(existing)
        guard !missing.isEmpty else { return }
        for achievement in AchievementID.allCases where missing.contains(achievement) {
            context.insert(AchievementUnlock(achievement: achievement, unlockedAt: date))
        }
        context.saveOrLog()
    }

    /// Backfills durable ownership for achievements already supported by the
    /// user's history. This runs without celebration so an app update never
    /// floods an established user with old rewards.
    @MainActor
    static func reconcile(
        goals: [Goal],
        context: ModelContext,
        date: Date = .now,
        calendar: Calendar = .current
    ) {
        let existing = Set(context.allAchievementUnlocks().compactMap(\.achievement))
        let progress = AchievementEngine.progress(
            in: AchievementSnapshot(goals: goals, calendar: calendar),
            asOf: date,
            calendar: calendar
        )
        let missing = AchievementID.allCases.filter {
            progress[$0]?.isUnlocked == true && !existing.contains($0)
        }
        record(missing, context: context, date: date)
    }
}
