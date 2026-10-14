import XCTest

/// Opt-in end-to-end tests. Credentials must belong to an isolated loopback QA server.
@MainActor
final class GoalsLiveSyncTests: XCTestCase {
    private let origin = "http://127.0.0.1:4308"
    private var token = ""

    func testPhoneAndMCPSeeEachOthersChangesAcrossRestart() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let email=env["WAI_GOALS_QA_EMAIL"], email.hasSuffix("@example.test"),
              let password=env["WAI_GOALS_QA_PASSWORD"], let key=env["WAI_GOALS_QA_TOKEN"] else {
            throw XCTSkip("Requires disposable QA account environment variables")
        }
        token=key
        continueAfterFailure=false
        let suffix=String(UUID().uuidString.prefix(8))
        let remoteTitle="QA server \(suffix)", phoneTitle="QA phone \(suffix)"
        let created=try await call("goals_create",["operationId":UUID().uuidString,"title":remoteTitle])
        let remoteID=try XCTUnwrap((created["goal"] as? [String:Any])?["id"] as? String)
        let app=XCUIApplication()
        app.launchEnvironment["WAI_GOALS_QA_ORIGIN"]=origin
        app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US"]
        app.launch()
        if app.buttons["Use password instead"].waitForExistence(timeout:5) {
            app.buttons["Use password instead"].tap()
            app.textFields["Email"].tap(); app.textFields["Email"].typeText(email)
            app.secureTextFields["Password"].tap(); app.secureTextFields["Password"].typeText(password)
            app.buttons["Sign in"].tap()
        }
        XCTAssertTrue(app.buttons["Goals"].firstMatch.waitForExistence(timeout:20))
        app.tabBars.buttons["Goals"].tap()
        XCTAssertTrue(app.navigationBars["Goals"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts[remoteTitle].waitForExistence(timeout:20))
        app.buttons["Add goal"].tap()
        XCTAssertTrue(app.textFields["Goal name"].waitForExistence(timeout:10))
        app.textFields["Goal name"].tap(); app.textFields["Goal name"].typeText(phoneTitle)
        app.buttons["Save"].tap()
        let phone=try await waitForGoal(phoneTitle)
        let phoneID=try XCTUnwrap(phone["id"] as? String)
        app.terminate()
        let read=try await call("goals_get",["id":remoteID])
        let newTitle="QA synced after restart \(suffix)"
        _=try await call("goals_update",["operationId":UUID().uuidString,"id":remoteID,
            "expectedRevision":try XCTUnwrap(read["revision"]),"patch":["title":newTitle]])
        app.launch()
        XCTAssertTrue(app.buttons["Goals"].firstMatch.waitForExistence(timeout:15))
        app.tabBars.buttons["Goals"].tap()
        XCTAssertTrue(app.navigationBars["Goals"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts[newTitle].waitForExistence(timeout:20))
        app.staticTexts[newTitle].tap()
        XCTAssertTrue(app.buttons["Mark done today"].waitForExistence(timeout:5))
        app.buttons["Mark done today"].tap()
        var count=0
        for _ in 0..<20 {
            let history=try await call("goals_history",["goalId":remoteID,"kind":"completions"])
            count=(history["total"] as? Int) ?? 0
            if count==1 { break }
            try await Task.sleep(for:.milliseconds(500))
        }
        XCTAssertEqual(count,1,"Phone completion must reach the MCP account")
        XCTAssertTrue(app.buttons["Done today"].waitForExistence(timeout:5),"Synced completion must also update the visible button")
        let screenshot=XCTAttachment(screenshot:app.screenshot());screenshot.name="Live Goals sync";screenshot.lifetime = .keepAlways;add(screenshot)
        for id in [remoteID,phoneID] {
            let latest=try await call("goals_get",["id":id])
            _=try await call("goals_delete",["operationId":UUID().uuidString,"id":id,"expectedRevision":try XCTUnwrap(latest["revision"])])
        }
        app.terminate();app.launch()
        XCTAssertTrue(app.tabBars.buttons["Goals"].waitForExistence(timeout:20),"Remote deletion must not crash rows holding an old model")
        app.tabBars.buttons["Goals"].tap()
        XCTAssertTrue(app.navigationBars["Goals"].waitForExistence(timeout:10))
        XCTAssertFalse(app.staticTexts[newTitle].exists)
        XCTAssertFalse(app.staticTexts[phoneTitle].exists)
    }

    private func waitForGoal(_ title:String) async throws -> [String:Any] {
        for _ in 0..<30 {
            let result=try await call("goals_list",["query":title])
            if let goal=(result["goals"] as? [[String:Any]])?.first { return goal }
            try await Task.sleep(for:.milliseconds(500))
        }
        XCTFail("The goal created in the phone UI did not reach MCP")
        return [:]
    }

    private func call(_ name:String,_ args:[String:Any]) async throws -> [String:Any] {
        var request=URLRequest(url:URL(string:origin+"/api/goals/mcp")!)
        request.httpMethod="POST"
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        request.httpBody=try JSONSerialization.data(withJSONObject:["jsonrpc":"2.0","id":UUID().uuidString,
            "method":"tools/call","params":["name":name,"arguments":args]])
        let (data,response)=try await URLSession.shared.data(for:request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode,200)
        let rpc=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        let result=try XCTUnwrap(rpc["result"] as? [String:Any])
        XCTAssertNil(result["isError"])
        let content=try XCTUnwrap(result["content"] as? [[String:Any]])
        let text=try XCTUnwrap(content.first?["text"] as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any])
    }
}
