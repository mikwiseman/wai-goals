import XCTest
@testable import WaiGoals

@MainActor final class ConversationRecoveryTests: XCTestCase {
    func testPendingCommandRestoresExactBodyAndIdentityAfterRelaunch() throws {
        let name = "qa-conversation-" + UUID().uuidString
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(name + ".json")
        defer { try? FileManager.default.removeItem(at: path) }
        let chat = Conversation(name: name)
        let original = try chat.prepare(text: "План", context: "2026-10-08", body: Data("original history".utf8))
        let restored = Conversation(name: name)
        let retry = try restored.prepare(text: "План", context: "2026-10-08", body: Data("changed history".utf8))
        XCTAssertEqual(original.id, retry.id); XCTAssertEqual(original.body, retry.body)
        XCTAssertEqual(restored.lines.count, 1); XCTAssertEqual(restored.draft, "План")
        try restored.complete("Сохранено")
        let completed = Conversation(name: name)
        XCTAssertNil(completed.pending); XCTAssertEqual(completed.lines.count, 2); XCTAssertTrue(completed.draft.isEmpty)
    }
    func testUnreadableHistoryIsPreservedAndCannotSendANewCommand() throws {
        let name = "qa-corrupt-" + UUID().uuidString
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(name + ".json")
        defer { try? FileManager.default.removeItem(at: path) }
        let original = Data("incomplete history".utf8); try original.write(to: path)
        let chat = Conversation(name: name)
        XCTAssertNotNil(chat.storageError)
        XCTAssertThrowsError(try chat.prepare(text: "New", context: "", body: Data()))
        XCTAssertEqual(try Data(contentsOf: path), original)
    }
    func testDictationPersistsAudioWhenTranscriptionFailsAndIgnoresLateResults() async throws {
        let key = "qa-audio-" + UUID().uuidString
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try Data("audio".utf8).write(to: path); UserDefaults.standard.set(path.path, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key); try? FileManager.default.removeItem(at: path) }
        let voice = ConversationVoice(draftKey: key)
        voice.transcribe = { _ in throw URLError(.notConnectedToInternet) }
        voice.retryDraft()
        for _ in 0..<100 where voice.phase != .idle { await Task.yield() }
        XCTAssertTrue(voice.hasDraft); XCTAssertNotNil(voice.error)
        var continuation: CheckedContinuation<String?, Error>?
        voice.transcribe = { _ in try await withCheckedThrowingContinuation { continuation = $0 } }
        var received = false; voice.receive = { _, _ in received = true }
        voice.retryDraft()
        while continuation == nil { await Task.yield() }
        voice.suspend(); continuation?.resume(returning: "Late answer")
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(received); XCTAssertTrue(voice.hasDraft); XCTAssertFalse(voice.live)
        voice.transcribe = { _ in "Editable draft" }
        voice.receive = { text, live in XCTAssertEqual(text,"Editable draft"); XCTAssertFalse(live); received = true }
        voice.retryDraft()
        for _ in 0..<100 where voice.phase != .idle { await Task.yield() }
        XCTAssertTrue(received); XCTAssertFalse(voice.hasDraft)
    }
    func testDeniedMicrophoneAndTextRepliesNeverStartPlayback() async {
        let voice = ConversationVoice(draftKey: "qa-denied-" + UUID().uuidString)
        voice.requestPermission = { false }
        voice.toggleLive()
        for _ in 0..<100 where voice.permissionPending { await Task.yield() }
        XCTAssertEqual(voice.phase,.idle); XCTAssertFalse(voice.live); XCTAssertNotNil(voice.error)
        var synthesized = false; voice.synthesize = { _ in synthesized = true; return Data() }
        await voice.readReply("Text answer")
        XCTAssertFalse(synthesized)
    }
}
