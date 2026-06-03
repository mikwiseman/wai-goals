import Foundation
import SwiftData

extension Goal {
    /// Toggles completion for `date` (default: today).
    ///
    /// Returns the new **current streak** if the goal just became completed for
    /// that day (so the caller can celebrate milestones); returns `nil` when the
    /// completion was removed.
    @discardableResult
    func toggleCompletion(on date: Date = .now, context: ModelContext, calendar: Calendar = .current) -> Int? {
        let day = calendar.startOfDay(for: date)

        if let existing = completions.first(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
            context.delete(existing)
            context.saveOrLog()
            return nil
        }

        let completion = Completion(day: day, goal: self)
        context.insert(completion)
        context.saveOrLog()

        // Compute the streak from an explicit day set so we don't depend on the
        // relationship array having synchronized yet.
        var days = completedDays(calendar: calendar)
        days.insert(day)
        return StreakCalculator.streak(schedule: schedule, completedDays: days, asOf: day, calendar: calendar).current
    }
}

/// Carries milestone celebration data to a presenting view.
struct MilestoneInfo: Identifiable, Equatable {
    let id = UUID()
    let streak: Int
    let unit: StreakUnit
    let accent: AccentToken
}
