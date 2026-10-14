import Foundation
import SwiftData

/// Lives in the same transaction as the goals. A crash cannot commit a pull without its baseline.
@Model
final class GoalsSyncMetadata {
    @Attribute(.unique) var accountID: String
    var revision: Int = 0
    var baselineData: Data?
    var pendingData: Data?
    var lastSyncedAt: Date?
    init(accountID: String) { self.accountID = accountID }
}
