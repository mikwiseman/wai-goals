import Foundation
import SwiftData

/// A single "done" record for a goal on a given day. There is at most one
/// completion per goal per calendar day (binary done/not-done tracking).
@Model
final class Completion {
    var id: UUID = UUID()
    /// The day this completion belongs to, normalized to local start-of-day.
    var day: Date = Date.now
    /// Calendar-day identity is stable when the device changes time zone.
    var syncDay: String?
    var goal: Goal?

    init(id: UUID = UUID(), day: Date, goal: Goal? = nil) {
        self.id = id
        self.day = day
        self.goal = goal
    }
}
