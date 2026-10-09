import XCTest
@testable import WaiGoals

@MainActor final class DictationCancellationTests: XCTestCase {
    func testCancelDiscardsOnlyCurrentAudioAndIgnoresLateTranscription() async throws {
        let key = "qa-cancel-audio-" + UUID().uuidString
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        try Data("test audio".utf8).write(to: url)
        UserDefaults.standard.set(url.path, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key); try? FileManager.default.removeItem(at: url) }
        let voice = ConversationVoice(draftKey: key)
        var completion: CheckedContinuation<String?, Error>?
        voice.transcribe = { _ in try await withCheckedThrowingContinuation { completion = $0 } }
        var delivered = false
        voice.receive = { _, _ in delivered = true }
        voice.retryDraft()
        while completion == nil { await Task.yield() }
        voice.cancelDictation()
        completion?.resume(returning: "Must not reach the draft")
        for _ in 0..<30 { await Task.yield() }
        XCTAssertFalse(delivered)
        XCTAssertFalse(voice.hasDraft)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(voice.phase, .idle)
        XCTAssertFalse(voice.live)
    }
}
