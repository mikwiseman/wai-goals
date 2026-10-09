import Foundation

struct ConversationLine: Codable, Identifiable {
    var id = UUID()
    var role: String
    var text: String
    var images: [Data]?
}
struct ConversationPending: Codable {
    var id: UUID
    var text: String
    var context: String
    var body: Data
    var images: [Data]?
}
@MainActor @Observable
final class Conversation {
    var lines: [ConversationLine] = []
    var draft = ""
    var photos: [Data] = []
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
                lines = saved.lines; draft = saved.draft; pending = saved.pending; photos = saved.photos ?? []
            }
        } catch { storageError = "История на устройстве не прочитана. Исходный файл сохранён." }
    }
    private struct Saved: Codable { var lines: [ConversationLine]; var draft: String; var pending: ConversationPending?; var photos: [Data]? }
    func save() throws {
        guard storageError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try JSONEncoder().encode(Saved(lines: Array(lines.suffix(200)), draft: draft, pending: pending, photos: photos)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func prepare(text: String, context: String, body: Data, images: [Data] = []) throws -> ConversationPending {
        if let pending, pending.text == text, pending.context == context, (pending.images ?? []) == images { try save(); return pending }
        let value = ConversationPending(id: UUID(), text: text, context: context, body: body, images: images)
        pending = value
        lines.append(ConversationLine(id: value.id, role: "user", text: text, images: images.isEmpty ? nil : images))
        draft = text
        try save()
        return value
    }
    func complete(_ text: String) throws {
        let previous = Saved(lines: lines, draft: draft, pending: pending, photos: photos)
        lines.append(ConversationLine(role: "assistant", text: text))
        pending = nil; draft = ""; photos = []
        do { try save() }
        catch { lines = previous.lines; draft = previous.draft; pending = previous.pending; photos = previous.photos ?? []; throw error }
    }
    var history: [[String: String]] { lines.suffix(24).map { ["role": $0.role, "text": $0.text] } }
}
