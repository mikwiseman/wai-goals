import Foundation

@MainActor
enum GoalsSnapshot {
    static func make(goals: [Goal], deviceId: UUID, journal: [JournalEntry] = [], now: Date = .now, calendar: Calendar = .current) throws -> Data {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = calendar.date(byAdding: .day, value: -90, to: calendar.startOfDay(for: now))!
        let today = calendar.startOfDay(for: now)
        func days(_ dates: [Date]) -> [String] {
            Array(Set(dates.filter { $0 >= cutoff && calendar.startOfDay(for: $0) <= today }.map { formatter.string(from: $0) })).sorted()
        }
        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let records: [[String: Any]] = goals.sorted { $0.sortIndex < $1.sortIndex }.map { goal in
            ["id": goal.id.uuidString, "title": goal.title,
             "why": goal.personalWhy as Any? ?? NSNull(), "smallStep": goal.smallStep as Any? ?? NSNull(),
             "archived": goal.isArchived, "schedule": goal.schedule.summary(calendar: calendar),
             "completedDays": days(goal.completions.map(\.day)), "intendedDays": days(goal.intentions.map(\.day))]
        }
        let journalRecords: [[String: Any]] = journal
            .filter { $0.periodKey >= formatter.string(from: cutoff) }
            .sorted { $0.updatedAt > $1.updatedAt }.prefix(240).map { entry in
                ["id": entry.id.uuidString, "kind": entry.kindRaw, "period": entry.periodKey,
                 "text": entry.text, "insight": entry.insight as Any? ?? NSNull(),
                 "updatedAt": timestamp.string(from: entry.updatedAt)]
            }
        return try JSONSerialization.data(withJSONObject: ["deviceId":deviceId.uuidString, "capturedAt":timestamp.string(from:now), "timezone":calendar.timeZone.identifier, "historyStart":formatter.string(from:cutoff), "goals":records, "journal":journalRecords], options:[.sortedKeys])
    }
}
