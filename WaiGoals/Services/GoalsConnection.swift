import Foundation
import Observation
import Security

@MainActor @Observable
final class GoalsConnection {
    static let shared = GoalsConnection()
    private struct Credential: Codable { let token: String; let deviceId: UUID }
    private let service = "is.waiwai.goals.connection"
    private let origin = "https://money.waiwai.is"
    private var credential: Credential?
    private var pending: Data?
    private var syncing = false
    var busy = false
    var status: String?
    var lastSyncedAt: Date? = UserDefaults.standard.object(forKey: "goals.lastSyncedAt") as? Date
    var isConnected: Bool { credential != nil }
    private init() {
        var result: CFTypeRef?
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data=result as? Data {
            credential = try? JSONDecoder().decode(Credential.self,from:data)
        }
    }
    func connect(email: String, password: String, goals: [Goal], journal: [JournalEntry] = []) async {
        guard !busy, !isConnected else { return }
        busy=true; status=nil
        defer { busy=false }
        do {
            let login=try await request(path:"/api/auth/sign-in/email",method:"POST",body:JSONSerialization.data(withJSONObject:["email":email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased(),"password":password]))
            guard let object=try JSONSerialization.jsonObject(with:login) as? [String:Any],let session=object["token"] as? String else { throw ConnectionError.message("Could not sign in. Check your WaiMoney account.") }
            let data=try await request(path:"/api/goals/connection",method:"POST",token:session)
            guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let token=object["token"] as? String else { throw ConnectionError.message("Could not connect. Please try again.") }
            let deviceId = UserDefaults.standard.string(forKey: "goals.deviceId").flatMap(UUID.init(uuidString:)) ?? UUID()
            let value=Credential(token:token,deviceId:deviceId)
            let stored=try JSONEncoder().encode(value)
            let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service]
            SecItemDelete(query as CFDictionary)
            var attributes=query;attributes[kSecValueData as String]=stored;attributes[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(attributes as CFDictionary,nil)==errSecSuccess else {
                _ = try? await request(path:"/api/goals/connection",method:"DELETE",token:token,body:JSONSerialization.data(withJSONObject:["deviceId":deviceId.uuidString]))
                throw ConnectionError.message("Could not save the connection securely.")
            }
            credential=value
            UserDefaults.standard.set(deviceId.uuidString, forKey: "goals.deviceId")
            await sync(goals:goals, journal:journal)
        } catch { status=error.localizedDescription }
    }
    func sync(goals: [Goal], journal: [JournalEntry] = []) async {
        guard let connection=credential else { return }
        do { pending=try GoalsSnapshot.make(goals:goals,deviceId:connection.deviceId, journal:journal) }
        catch { status="Could not prepare your goals for syncing.";return }
        guard !syncing else { return }
        syncing=true
        defer { syncing=false }
        while let body=pending {
            pending=nil
            do {
                _ = try await request(path:"/api/goals/snapshot",method:"PUT",token:connection.token,body:body)
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
    func disconnect() async {
        guard let connection=credential,!busy,!syncing else { return }
        busy=true;defer{busy=false}
        do {
            _ = try await request(path:"/api/goals/connection",method:"DELETE",token:connection.token,body:JSONSerialization.data(withJSONObject:["deviceId":connection.deviceId.uuidString]))
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
        let data = try await request(path:"/api/goals/reflect", method:"POST", token:credential.token, body:body, timeout:150)
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
        let data = try await request(path:"/api/goals/transcribe", method:"POST", token:credential.token, body:body, contentType:"multipart/form-data; boundary=\(boundary)", timeout:90)
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
        return try JSONDecoder().decode(ConversationReply.self, from: await request(path: "/api/goals/message", method: "POST", token: credential.token, body: command.body, timeout: 150, requestId: command.id))
    }
    func speech(_ text: String) async throws -> Data {
        guard let credential else { throw ConnectionError.unauthorized }
        return try await request(path: "/api/goals/speech", method: "POST", token: credential.token, body: JSONSerialization.data(withJSONObject: ["text": text]), timeout: 90)
    }
    private func clearCredential() {
        if let credential { UserDefaults.standard.set(credential.deviceId.uuidString, forKey: "goals.deviceId") }
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)
        credential=nil;pending=nil;lastSyncedAt=nil
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
            if http.statusCode==401 || http.statusCode==403 { throw ConnectionError.unauthorized }
            if let object = try? JSONSerialization.jsonObject(with:data) as? [String:Any], let message = object["error"] as? String, http.statusCode < 500 {
                throw ConnectionError.message(String(message.prefix(300)))
            }
            throw ConnectionError.message("Connection unavailable (\(http.statusCode)). Your goals are safe on this device.")
        }
        return data
    }
    private enum ConnectionError: LocalizedError {
        case unauthorized
        case message(String)
        var errorDescription:String? {
            switch self {
            case .unauthorized: "Sign-in was not accepted. Check your WaiMoney email and password."
            case .message(let text): text
            }
        }
    }
}
