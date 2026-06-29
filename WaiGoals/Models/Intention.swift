import Foundation
import SwiftData

/// A daily commitment to act on a goal before it is completed. Intention and
/// completion stay separate so a morning pledge never changes progress stats.
@Model
final class Intention {
    static let pledgeText = "I hereby commit to doing my best to complete this goal today."

    var id: UUID = UUID()
    /// The day this intention belongs to, normalized to local start-of-day.
    var day: Date = Date.now
    /// Retained only so older TestFlight data can migrate cleanly.
    var cueRaw: String = ""
    var approvedAt: Date = Date.now
    var goal: Goal?

    init(
        id: UUID = UUID(),
        day: Date,
        approvedAt: Date = .now,
        goal: Goal? = nil
    ) {
        self.id = id
        self.day = day
        self.approvedAt = approvedAt
        self.goal = goal
    }
}
