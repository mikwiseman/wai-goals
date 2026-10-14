import Foundation
import Observation
import Security
import CryptoKit
import SwiftData

@MainActor @Observable
final class GoalsConnection {
    static let shared = GoalsConnection()
    private struct Credential: Codable { let token: String; let deviceId: UUID; var userId: String?; var independent: Bool?
        var prefix: String { independent == true ? "/api/goals/account" : "/api/goals" }
        var bindingKey: String { independent == true ? "goals.independentAccountId" : "goals.boundAccountId" }
    }
    private let service = "is.waiwai.goals.connection"
    private let origin: String = {
        #if DEBUG && targetEnvironment(simulator)
        // Acceptance tests can use only a loopback server in a separate simulator.
        if let value=ProcessInfo.processInfo.environment["WAI_GOALS_QA_ORIGIN"],
           let url=URL(string:value),url.scheme == "http",url.host == "127.0.0.1" { return value }
        #endif
        return "https://money.waiwai.is"
    }()
    private var credential: Credential?
    private var pending: Data?
    private var syncing = false
    private var syncAgain = false
    var syncConflict: GoalsSyncConflict?
    private var conflictBase: GoalsSyncDocument?
    private var conflictRemote: GoalsSyncResponse?
    var busy = false
    var status: String?
    var aiAvailable: Bool?
    var lastSyncedAt: Date? = UserDefaults.standard.object(forKey: "goals.lastSyncedAt") as? Date
    var accountIdentifier: String? { credential?.userId.map { (credential?.independent == true ? "goals:" : "legacy:") + $0 } }
    var conversationName: String { Self.conversationName(for: accountIdentifier) }
    static func conversationName(for accountID: String?) -> String {
        guard let accountID else { return "goals-conversation-unclaimed" }
        let key = SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
        return "goals-conversation-" + key
    }
    var isConnected: Bool { credential != nil }
    var isLegacyConnection: Bool { credential != nil && credential?.independent != true }
    var mcpToken: String?
    struct MCPAccess: Decodable, Identifiable { let id: String; let name: String }
    var mcpAccess: [MCPAccess] = []
    var mcpURL: String { origin + "/api/goals/mcp" }
    private init() {
        var result: CFTypeRef?
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data=result as? Data {
            credential = try? JSONDecoder().decode(Credential.self,from:data)
            if credential?.independent == true { aiAvailable = false }
        }
        if let directory = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            let old = directory.appendingPathComponent("goals-conversation.json")
            if FileManager.default.fileExists(atPath: old.path) {
                var destination = directory.appendingPathComponent(conversationName + ".json")
                if FileManager.default.fileExists(atPath: destination.path) { destination = directory.appendingPathComponent("goals-conversation-archive-" + UUID().uuidString + ".json") }
                do { try FileManager.default.moveItem(at: old, to: destination) }
                catch { status = "Не удалось открыть прежнюю историю. Исходный файл сохранён." }
            }
        }
    }
    func chatGPTConnection(method: String) async throws -> ChatGPTConnectionStatus {
        guard let credential else { throw ConnectionError.unauthorized }
        if credential.independent != true {
            await refreshStatus()
            return ChatGPTConnectionStatus(status: aiAvailable == true ? "connected" : "disconnected", aiAvailable: aiAvailable, voiceAvailable: aiAvailable, managed: false)
        }
        let data = try await request(path: credential.prefix + "/chatgpt", method: method, token: credential.token)
        guard self.credential?.token == credential.token else { throw CancellationError() }
        let result = try JSONDecoder().decode(ChatGPTConnectionStatus.self, from: data)
        aiAvailable = result.canChat
        return result
    }
    func sendCode(email: String) async -> Bool {
        guard !busy else { return false }
        busy=true;status=nil;defer{busy=false}
        do {
            _ = try await request(path:"/api/goals/auth/email-otp/send-verification-otp",method:"POST",body:JSONSerialization.data(withJSONObject:["email":email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased(),"type":"sign-in"]))
            return true
        } catch { status=error.localizedDescription;return false }
    }
    func connect(email: String, password: String = "", name: String? = nil, code: String? = nil, context: ModelContext) async {
        guard !busy, !syncing, !isConnected || isLegacyConnection else { return }
        busy=true;status=nil;defer{busy=false}
        do {
            var fields=["email":email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()]
            if let code { fields["otp"]=code.trimmingCharacters(in:.whitespacesAndNewlines) }
            else { fields["password"]=password }
            if let name { fields["name"]=name.trimmingCharacters(in:.whitespacesAndNewlines) }
            let path=code != nil ? "/api/goals/auth/sign-in/email-otp" : name == nil ? "/api/goals/auth/sign-in/email" : "/api/goals/auth/sign-up/email"
            let login=try await request(path:path,method:"POST",body:JSONSerialization.data(withJSONObject:fields))
            guard let object=try JSONSerialization.jsonObject(with:login) as? [String:Any],let token=object["token"] as? String,
                  let user=object["user"] as? [String:Any],let userId=user["id"] as? String else {
                throw ConnectionError.message("Could not sign in. Please try again.")
            }
            if let boundId=UserDefaults.standard.string(forKey:"goals.independentAccountId"),boundId != userId {
                _ = try? await request(path:"/api/goals/auth/sign-out",method:"POST",token:token,body:Data("{}".utf8))
                throw ConnectionError.message("The goals on this device belong to another Goals account. Sign in to that account to keep your data separate.")
            }
            let deviceId=UserDefaults.standard.string(forKey:"goals.deviceId").flatMap(UUID.init(uuidString:)) ?? UUID()
            let value=Credential(token:token,deviceId:deviceId,userId:userId,independent:true)
            let stored=try JSONEncoder().encode(value)
            let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service]
            // Update atomically so a failed Keychain write preserves the previous connection.
            var attributes:[String:Any]=[kSecValueData as String:stored,kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
            var result=SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
            if result == errSecItemNotFound {
                attributes.merge(query){a,_ in a};result=SecItemAdd(attributes as CFDictionary,nil)
            }
            guard result == errSecSuccess else {
                _ = try? await request(path:"/api/goals/auth/sign-out",method:"POST",token:token,body:Data("{}".utf8))
                throw ConnectionError.message("Could not save the connection securely.")
            }
            let previous=credential
            credential=value;aiAvailable=false;lastSyncedAt=nil
            UserDefaults.standard.set(userId,forKey:value.bindingKey)
            UserDefaults.standard.set(deviceId.uuidString,forKey:"goals.deviceId")
            await sync(context:context,force:true)
            if let previous, previous.independent != true, lastSyncedAt != nil {
                _ = try? await request(path:previous.prefix+"/connection",method:"DELETE",token:previous.token,body:JSONSerialization.data(withJSONObject:["deviceId":previous.deviceId.uuidString]))
            }
        } catch { status=error.localizedDescription }
    }
    func refreshStatus() async {
        guard let credential else { return }
        do {
            let data=try await request(path:credential.prefix+"/connection",method:"GET",token:credential.token)
            guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let userId=object["userId"] as? String,
                  self.credential?.token == credential.token else { return }
            aiAvailable=object["aiAvailable"] as? Bool
            UserDefaults.standard.set(userId,forKey:credential.bindingKey)
        } catch { /* A temporary status failure must not sign out a valid session. */ }
    }
    func sync(context: ModelContext, force: Bool = false) async {
        guard !busy || force else { return }
        guard let connection=credential else { return }
        if UserDefaults.standard.string(forKey:connection.bindingKey) == nil { await refreshStatus() }
        if connection.independent == true {
            await syncAccount(context:context,connection:connection)
            return
        }
        do { pending=try GoalsSnapshot.make(goals:context.fetch(FetchDescriptor<Goal>()),deviceId:connection.deviceId, journal:context.fetch(FetchDescriptor<JournalEntry>())) }
        catch { status="Could not prepare your goals for syncing.";return }
        guard !syncing else { return }
        syncing=true
        defer { syncing=false }
        while let body=pending {
            pending=nil
            do {
                _ = try await request(path:connection.prefix+"/snapshot",method:"PUT",token:connection.token,body:body)
                guard credential?.token == connection.token else { return }
                lastSyncedAt = .now
                UserDefaults.standard.set(lastSyncedAt,forKey:"goals.lastSyncedAt")
                status=nil
            } catch ConnectionError.unauthorized {
                clearCredential()
                status="Connection expired. Sign in again to resume syncing. Your goals are safe on this device."
                return
            } catch { status="Not synced. \(error.localizedDescription)"; return }
        }
    }
    private func syncAccount(context: ModelContext, connection: Credential) async {
        guard syncConflict == nil else { return }
        guard !syncing else { syncAgain=true; return }
        syncing=true; defer { syncing=false }
        do {
            guard let accountID=connection.userId else { throw ConnectionError.unauthorized }
            let session=try GoalsSyncSession(context:context,accountID:accountID,deviceID:connection.deviceId)
            for _ in 0..<4 {
                syncAgain=false
                let pending=try session.prepare()
                let response: GoalsSyncResponse
                do {
                    response=try GoalsSyncCoding.decoder().decode(GoalsSyncResponse.self,from:await request(path:connection.prefix+"/sync",method:"POST",token:connection.token,body:GoalsSyncCoding.encoder().encode(pending.request)))
                } catch ConnectionError.conflict {
                    let remote=try await fetchSync(connection)
                    let base=try session.baseline()
                    if try showConflict(base:base,remote:remote,context:context) { return }
                    // A fresh pull may already contain the requested result. Rebase without dropping local edits.
                    try session.resolve(remote,base:base,preferLocal:false)
                    continue
                }
                guard credential?.token == connection.token else { return }
                do { try session.accept(response,pending:pending) }
                catch let conflict as GoalsSyncConflict {
                    syncConflict=conflict; conflictBase=pending.local; conflictRemote=response; status=conflict.localizedDescription
                    return
                }
                lastSyncedAt=session.metadata.lastSyncedAt
                UserDefaults.standard.set(lastSyncedAt,forKey:"goals.lastSyncedAt")
                status=nil
                NotificationCenter.default.post(name:.goalsDidSync,object:nil)
                let remaining=try GoalsSyncDocument.capture(context).changes(since:session.baseline())
                if remaining.isEmpty && !syncAgain && pending.request.lastAppliedRevision == response.revision { return }
            }
        } catch ConnectionError.unauthorized {
            clearCredential(); status="Connection expired. Sign in again to resume syncing. Your goals and queued changes are safe on this device."
        } catch { status="Not synced. \(error.localizedDescription)" }
    }
    private func fetchSync(_ connection: Credential) async throws -> GoalsSyncResponse {
        let data=try await request(path:connection.prefix+"/sync",method:"GET",token:connection.token)
        guard credential?.token == connection.token else { throw CancellationError() }
        return try GoalsSyncCoding.decoder().decode(GoalsSyncResponse.self,from:data)
    }
    private func showConflict(base: GoalsSyncDocument, remote: GoalsSyncResponse, context: ModelContext) throws -> Bool {
        do { _ = try GoalsSyncDocument.merge(base:base,local:GoalsSyncDocument.capture(context),remote:remote.state); return false }
        catch let conflict as GoalsSyncConflict {
            conflictBase=base; conflictRemote=remote; syncConflict=conflict; status=conflict.localizedDescription; return true
        }
    }
    func resolveSyncConflict(context: ModelContext, preferLocal: Bool) async {
        guard let connection=credential, let accountID=connection.userId, let base=conflictBase,
              let displayed=conflictRemote, !busy, !syncing else { return }
        busy=true
        do {
            let latest=try await fetchSync(connection)
            if latest.revision != displayed.revision {
                if try showConflict(base:base,remote:latest,context:context) {
                    status="The server changed again. Review the latest versions before choosing."; busy=false; return
                }
            }
            let session=try GoalsSyncSession(context:context,accountID:accountID,deviceID:connection.deviceId)
            try session.resolve(latest,base:base,preferLocal:preferLocal)
            syncConflict=nil; conflictBase=nil; conflictRemote=nil; status=nil
            busy=false
            await sync(context:context)
        } catch { status=error.localizedDescription; busy=false }
    }
    func disconnect() async {
        guard let connection=credential,!busy,!syncing else { return }
        busy=true;defer{busy=false}
        do {
            await refreshStatus()
            let data = try await request(path:connection.prefix+"/connection",method:"DELETE",token:connection.token,body:JSONSerialization.data(withJSONObject:["deviceId":connection.deviceId.uuidString]))
            if let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let userId=object["userId"] as? String {
                UserDefaults.standard.set(userId,forKey:connection.bindingKey)
            }
            clearCredential()
            status=nil
        } catch ConnectionError.unauthorized {
            clearCredential()
            status="Connection expired. Sign in again to manage the saved snapshot."
        } catch { status=error.localizedDescription }
    }
    func reflect(entry: JournalEntry) async throws -> String {
        guard let credential else { throw ConnectionError.unauthorized }
        let body = try JSONSerialization.data(withJSONObject: ["kind":entry.kindRaw, "period":entry.periodKey, "text":entry.text, "timezone":TimeZone.current.identifier])
        let data = try await request(path:credential.prefix+"/reflect", method:"POST", token:credential.token, body:body, timeout:150)
        guard let object = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let insight = object["insight"] as? String, !insight.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {
            throw ConnectionError.message("Разбор не завершён. Запись сохранена — можно попробовать снова.")
        }
        return insight
    }
    func transcribe(audio: Data) async throws -> String {
        guard let credential else { throw ConnectionError.unauthorized }
        let boundary = UUID().uuidString
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\nContent-Type: audio/m4a\r\n\r\n".utf8)
        body.append(audio)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let data = try await request(path:credential.prefix+"/transcribe", method:"POST", token:credential.token, body:body, contentType:"multipart/form-data; boundary=\(boundary)", timeout:90)
        guard let object = try JSONSerialization.jsonObject(with:data) as? [String:Any], let text = object["text"] as? String, !text.isEmpty else {
            throw ConnectionError.message("Не удалось услышать речь. Запись можно распознать ещё раз.")
        }
        return text
    }
    struct ConversationReply: Decodable {
        struct Journal: Decodable { var kind: JournalKind; var period: String; var text: String }
        var reply: String
        var journal: Journal?
    }
    func message(_ command: ConversationPending) async throws -> ConversationReply {
        guard let credential else { throw ConnectionError.unauthorized }
        return try JSONDecoder().decode(ConversationReply.self, from: await request(path: credential.prefix+"/message", method: "POST", token: credential.token, body: command.body, timeout: 150, requestId: command.id))
    }
    func speech(_ text: String) async throws -> Data {
        guard let credential else { throw ConnectionError.unauthorized }
        return try await request(path: credential.prefix+"/speech", method: "POST", token: credential.token, body: JSONSerialization.data(withJSONObject: ["text": text]), timeout: 90)
    }
    func loadMCPAccess() async {
        guard let credential, credential.independent == true else { return }
        do { mcpAccess=try JSONDecoder().decode([MCPAccess].self,from:await request(path:credential.prefix+"/tokens",method:"GET",token:credential.token)) }
        catch { status=error.localizedDescription }
    }
    func createMCPAccess(canWrite: Bool = false) async {
        guard let credential, credential.independent == true,!busy else { return }
        busy=true;status=nil;defer{busy=false}
        do {
            let data=try await request(path:credential.prefix+"/tokens",method:"POST",token:credential.token,body:JSONSerialization.data(withJSONObject:["name":"Assistant","scopes":canWrite ? ["goals:read","goals:write"] : ["goals:read"]]))
            mcpToken=(try JSONSerialization.jsonObject(with:data) as? [String:Any])?["token"] as? String
            await loadMCPAccess()
        } catch { status=error.localizedDescription }
    }
    func revokeMCPAccess(id:String) async {
        guard let credential,credential.independent == true,!busy else { return }
        busy=true;status=nil;defer{busy=false}
        do {
            _ = try await request(path:credential.prefix+"/tokens",method:"DELETE",token:credential.token,body:JSONSerialization.data(withJSONObject:["id":id]))
            mcpToken=nil;await loadMCPAccess()
        } catch { status=error.localizedDescription }
    }
    func deleteAccount(password:String) async {
        guard let credential,credential.independent == true,!busy else { return }
        busy=true;status=nil;defer{busy=false}
        do {
            var fields:[String:String]=[:];if !password.isEmpty { fields["password"]=password }
            _ = try await request(path:"/api/goals/auth/delete-user",method:"POST",token:credential.token,body:JSONSerialization.data(withJSONObject:fields))
            clearCredential();UserDefaults.standard.removeObject(forKey:"goals.independentAccountId")
            status="Your Goals account and server data were deleted. Your goals remain on this device."
        } catch { status=error.localizedDescription }
    }
    private func clearCredential() {
        if let credential { UserDefaults.standard.set(credential.deviceId.uuidString, forKey: "goals.deviceId") }
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)
        credential=nil;pending=nil;lastSyncedAt=nil;aiAvailable=nil;mcpToken=nil;mcpAccess=[]
        syncConflict=nil;conflictBase=nil;conflictRemote=nil
        UserDefaults.standard.removeObject(forKey:"goals.lastSyncedAt")
    }
    private func request(path:String,method:String,token:String?=nil,body:Data?=nil, contentType:String="application/json", timeout:TimeInterval=30, requestId:UUID?=nil) async throws -> Data {
        var request=URLRequest(url:URL(string:origin+path)!)
        request.httpMethod=method;request.httpBody=body;request.timeoutInterval=timeout
        request.setValue(contentType,forHTTPHeaderField:"Content-Type")
        if let requestId { request.setValue(requestId.uuidString, forHTTPHeaderField:"Idempotency-Key") }
        if let token { request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        let session=URLSession(configuration:.ephemeral)
        defer{session.finishTasksAndInvalidate()}
        let(data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode==401 { throw ConnectionError.unauthorized }
            if http.statusCode==409 && path.hasSuffix("/sync") { throw ConnectionError.conflict }
            if let object = try? JSONSerialization.jsonObject(with:data) as? [String:Any], let message = (object["error"] as? String) ?? (object["message"] as? String), http.statusCode < 500 {
                throw ConnectionError.message(String(message.prefix(300)))
            }
            throw ConnectionError.message("Connection unavailable (\(http.statusCode)). Your goals are safe on this device.")
        }
        return data
    }
    private enum ConnectionError: LocalizedError {
        case unauthorized
        case conflict
        case message(String)
        var errorDescription:String? {
            switch self {
            case .unauthorized: "Sign-in was not accepted. Check your email and password."
            case .conflict: "Sync needs a choice. Your changes are saved on this device."
            case .message(let text): text
            }
        }
    }
}
