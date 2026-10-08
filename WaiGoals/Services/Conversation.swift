import Foundation

struct ConversationLine: Codable, Identifiable {
    var id = UUID()
    var role: String
    var text: String
}
struct ConversationPending: Codable {
    var id: UUID
    var text: String
    var context: String
    var body: Data
}
@MainActor @Observable
final class Conversation {
    var lines: [ConversationLine] = []
    var draft = ""
    var pending: ConversationPending?
    var storageError: String?
    private let url: URL
    init(name: String) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        url = folder.appendingPathComponent(name + ".json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: url))
                lines = saved.lines; draft = saved.draft; pending = saved.pending
            }
        } catch { storageError = "История на устройстве не прочитана. Исходный файл сохранён." }
    }
    private struct Saved: Codable { var lines: [ConversationLine]; var draft: String; var pending: ConversationPending? }
    func save() throws {
        guard storageError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try JSONEncoder().encode(Saved(lines: Array(lines.suffix(200)), draft: draft, pending: pending)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func prepare(text: String, context: String, body: Data) throws -> ConversationPending {
        if let pending, pending.text == text, pending.context == context { try save(); return pending }
        let value = ConversationPending(id: UUID(), text: text, context: context, body: body)
        pending = value
        lines.append(ConversationLine(id: value.id, role: "user", text: text))
        draft = text
        try save()
        return value
    }
    func complete(_ text: String) throws {
        let previous = Saved(lines: lines, draft: draft, pending: pending)
        lines.append(ConversationLine(role: "assistant", text: text))
        pending = nil; draft = ""
        do { try save() }
        catch { lines = previous.lines; draft = previous.draft; pending = previous.pending; throw error }
    }
    var history: [[String: String]] { lines.suffix(24).map { ["role": $0.role, "text": $0.text] } }
}
