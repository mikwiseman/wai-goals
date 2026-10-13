import XCTest
@testable import WaiGoals

@MainActor
final class ChatGPTConnectionTests: XCTestCase {
    @MainActor private final class NetworkState { var offline = false }
    func testConnectCancelReconnectAndRestoreUseOneAccount() async {
        let model = ChatGPTConnectionModel()
        var connected = false
        var calls: [String] = []
        model.configure(accountID: "first") { method in
            calls.append(method)
            if method == "POST" { return ChatGPTConnectionStatus(status: "pending", verificationUrl: "https://auth.openai.com/codex/device", userCode: "ABCD-1234", aiAvailable: false) }
            if method == "DELETE" { connected = false }
            return ChatGPTConnectionStatus(status: connected ? "connected" : "disconnected", email: connected ? "qa@example.invalid" : nil, aiAvailable: connected, voiceAvailable: false, managed: connected)
        }
        await model.refresh(); XCTAssertFalse(model.canChat)
        await model.start(); XCTAssertTrue(model.pending); XCTAssertNotNil(model.verificationURL)
        await model.disconnect(); XCTAssertFalse(model.pending); XCTAssertFalse(model.canChat)
        await model.start(); connected = true; await model.refresh()
        XCTAssertTrue(model.canChat); XCTAssertFalse(model.canUseVoice)
        await model.refresh(); XCTAssertTrue(model.canChat)
        await model.disconnect(); XCTAssertFalse(model.canChat)
        XCTAssertEqual(calls, ["GET", "POST", "DELETE", "POST", "GET", "GET", "DELETE"])
    }

    func testLateResultCannotConnectTheNextAccount() async {
        let model = ChatGPTConnectionModel()
        var continuation: CheckedContinuation<ChatGPTConnectionStatus, Never>?
        model.configure(accountID: "first") { _ in await withCheckedContinuation { continuation = $0 } }
        let oldRequest = Task { await model.start() }
        while continuation == nil { await Task.yield() }
        model.configure(accountID: "second") { _ in ChatGPTConnectionStatus(status: "disconnected", aiAvailable: false) }
        continuation?.resume(returning: ChatGPTConnectionStatus(status: "connected", email: "first@example.invalid", aiAvailable: true))
        await oldRequest.value
        XCTAssertNil(model.connection); XCTAssertFalse(model.canChat); XCTAssertFalse(model.busy)
        await model.refresh(); XCTAssertEqual(model.connection?.status, "disconnected")
    }

    func testOfflineRefreshPreservesConnectionAndRestoresAfterRetry() async {
        let model = ChatGPTConnectionModel()
        let network = NetworkState()
        model.configure(accountID: "first") { _ in
            if network.offline { throw URLError(.notConnectedToInternet) }
            return ChatGPTConnectionStatus(status: "connected", aiAvailable: true, voiceAvailable: false)
        }
        await model.refresh(); network.offline = true; await model.refresh()
        XCTAssertTrue(model.canChat); XCTAssertNotNil(model.problem); XCTAssertFalse(model.busy)
        network.offline = false; await model.refresh(); XCTAssertNil(model.problem)
    }

    func testOnlyTheOfficialDevicePageCanOpenAndSignedOutRequestsDoNothing() async {
        let model = ChatGPTConnectionModel()
        var requests = 0
        model.configure(accountID: nil) { _ in requests += 1; return ChatGPTConnectionStatus(status: "connected", aiAvailable: true) }
        await model.start(); await model.refresh(); XCTAssertEqual(requests, 0)
        for raw in ["http://auth.openai.com/codex/device", "https://auth.openai.com.example.com/codex/device", "https://example.com/", "https://user:pass@auth.openai.com/codex/device", "https://auth.openai.com:443/codex/device"] {
            model.connection = ChatGPTConnectionStatus(status: "pending", verificationUrl: raw)
            XCTAssertNil(model.verificationURL)
        }
    }
}
