import Foundation
import SwiftData
import os

private let persistenceLog = Logger(subsystem: "is.waiwai.goals", category: "persistence")

extension ModelContext {
    /// Saves, surfacing any failure loudly (logged always, trapped in debug)
    /// rather than silently degrading.
    func saveOrLog(_ function: StaticString = #function) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            persistenceLog.error("SwiftData save failed in \(String(describing: function), privacy: .public): \(error, privacy: .public)")
            assertionFailure("SwiftData save failed: \(error)")
        }
    }

    /// Fetches all goals, logging any failure. Returns `[]` only if the fetch
    /// genuinely throws (which is surfaced via the log + a debug trap).
    func allGoals(_ function: StaticString = #function) -> [Goal] {
        do {
            return try fetch(FetchDescriptor<Goal>())
        } catch {
            persistenceLog.error("Goal fetch failed in \(String(describing: function), privacy: .public): \(error, privacy: .public)")
            assertionFailure("Goal fetch failed: \(error)")
            return []
        }
    }

    func allAchievementUnlocks(_ function: StaticString = #function) -> [AchievementUnlock] {
        do {
            return try fetch(FetchDescriptor<AchievementUnlock>())
        } catch {
            persistenceLog.error("Achievement fetch failed in \(String(describing: function), privacy: .public): \(error, privacy: .public)")
            assertionFailure("Achievement fetch failed: \(error)")
            return []
        }
    }
}
