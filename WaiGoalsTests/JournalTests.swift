import Testing
import Foundation
import SwiftData
@testable import WaiGoals

@MainActor
struct JournalTests {
    @Test func weekStartsOnMondayAcrossYearAndDST() {
        let c = Cal.make(firstWeekday: 1)
        #expect(JournalKind.weekPlan.periodKey(for: Cal.day(2027, 1, 3, in: c), calendar: c) == "2026-12-28")
        #expect(JournalKind.weekReview.periodKey(for: Cal.day(2026, 3, 8, in: c), calendar: c) == "2026-03-02")
        #expect(JournalKind.dayPlan.periodKey(for: Cal.day(2026, 3, 8, in: c), calendar: c) == "2026-03-08")
    }
    @Test func planAndReviewAreSeparateAndEditingDoesNotDuplicate() throws {
        let container = try ModelContainer(for: JournalEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let date = Date()
        let first = try JournalEntry.save(kind: .dayPlan, date: date, text: "  Read a chapter  ", context: context)
        first.insight = "Old insight"
        let edited = try JournalEntry.save(kind: .dayPlan, date: date, text: "Read two chapters", context: context)
        _ = try JournalEntry.save(kind: .dayReview, date: date, text: "Read one, enjoyed it", context: context)
        #expect(edited.id == first.id)
        #expect(edited.insight == nil)
        #expect(try context.fetchCount(FetchDescriptor<JournalEntry>()) == 2)
        #expect(throws: JournalError.self) { try JournalEntry.save(kind: .weekPlan, date: date, text: " \n ", context: context) }
    }
    @Test func journalSurvivesStoreReopening() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let config = ModelConfiguration(url: dir.appendingPathComponent("journal.store"))
        let id: UUID
        do {
            let container = try ModelContainer(for: JournalEntry.self, configurations: config)
            let row = try JournalEntry.save(kind: .weekReview, date: .now, text: "Больше времени семье", context: container.mainContext)
            row.insight = "Оставить два свободных вечера"
            try container.mainContext.save()
            id = row.id
        }
        let reopened = try ModelContainer(for: JournalEntry.self, configurations: config)
        let row = try #require(reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).first)
        #expect(row.id == id)
        #expect(row.text == "Больше времени семье")
        #expect(row.insight == "Оставить два свободных вечера")
    }
}
