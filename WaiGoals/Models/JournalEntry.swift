import Foundation
import SwiftData

enum JournalKind: String, Codable, CaseIterable, Identifiable {
    case dayPlan, dayReview, weekPlan, weekReview
    var id: String { rawValue }
    var isWeekly: Bool { self == .weekPlan || self == .weekReview }
    var isPlan: Bool { self == .dayPlan || self == .weekPlan }
    var title: String {
        switch self {
        case .dayPlan: "План на день"
        case .dayReview: "Итоги дня"
        case .weekPlan: "План на неделю"
        case .weekReview: "Рефлексия недели"
        }
    }
    var prompt: String {
        switch self {
        case .dayPlan: "Что сегодня самое важное? Назови один–три результата."
        case .dayReview: "Что получилось? Что дало энергию? Что хочется изменить?"
        case .weekPlan: "Какой ты хочешь запомнить эту неделю? Что приблизит к этому?"
        case .weekReview: "Что сдвинулось вперёд? На что ушли время и силы? Что взять в следующую неделю?"
        }
    }
    func start(for date: Date, calendar: Calendar = .current) -> Date {
        var c = calendar
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return isWeekly ? c.dateInterval(of: .weekOfYear, for: date)!.start : c.startOfDay(for: date)
    }
    func periodKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start(for: date, calendar: calendar))
    }
}

enum JournalError: LocalizedError {
    case empty, tooLong
    var errorDescription: String? {
        switch self {
        case .empty: "Сначала напиши или надиктуй несколько слов."
        case .tooLong: "Запись слишком длинная. Оставь до 20 000 символов."
        }
    }
}

@Model
final class JournalEntry {
    var id: UUID
    var kindRaw: String
    var periodKey: String
    var text: String
    var insight: String?
    var createdAt: Date
    var updatedAt: Date
    var kind: JournalKind { JournalKind(rawValue: kindRaw) ?? .dayPlan }

    init(kind: JournalKind, date: Date, text: String, calendar: Calendar = .current) {
        id = UUID()
        kindRaw = kind.rawValue
        periodKey = kind.periodKey(for: date, calendar: calendar)
        self.text = text
        createdAt = .now
        updatedAt = .now
    }

    @MainActor @discardableResult
    static func save(kind: JournalKind, date: Date, text: String, context: ModelContext) throws -> JournalEntry {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw JournalError.empty }
        guard cleaned.count <= 20_000 else { throw JournalError.tooLong }
        let key = kind.periodKey(for: date)
        let raw = kind.rawValue
        let existing = try context.fetch(FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.periodKey == key && $0.kindRaw == raw })).first
        let row = existing ?? JournalEntry(kind: kind, date: date, text: cleaned)
        let previousText = row.text, previousInsight = row.insight, previousUpdate = row.updatedAt
        if existing == nil { context.insert(row) }
        if row.text != cleaned { row.insight = nil }
        row.text = cleaned
        row.updatedAt = .now
        do { try context.save() }
        catch {
            if existing == nil { context.delete(row) }
            else { row.text = previousText; row.insight = previousInsight; row.updatedAt = previousUpdate }
            throw error
        }
        NotificationCenter.default.post(name: .goalsDidSave, object: nil)
        return row
    }
}
