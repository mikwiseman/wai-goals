import SwiftUI
import SafariServices

struct ChatGPTConnectionStatus: Codable, Equatable {
    var status: String
    var email: String? = nil
    var verificationUrl: String? = nil
    var userCode: String? = nil
    var expiresAt: String? = nil
    var error: String? = nil
    var aiAvailable: Bool? = nil
    var voiceAvailable: Bool? = nil
    var managed: Bool? = nil
    var canChat: Bool { aiAvailable == true }
}

@MainActor @Observable
final class ChatGPTConnectionModel {
    var connection: ChatGPTConnectionStatus?
    var problem: String?
    var busy = false
    private var accountID: String?
    private var generation = UUID()
    private var request: (@MainActor (String) async throws -> ChatGPTConnectionStatus)?
    var canChat: Bool { connection?.canChat == true }
    var canUseVoice: Bool { connection?.voiceAvailable == true }
    var pending: Bool { connection?.status == "pending" }

    func configure(accountID: String?, request: @escaping @MainActor (String) async throws -> ChatGPTConnectionStatus) {
        guard self.accountID != accountID || self.request == nil else { return }
        generation = UUID(); self.accountID = accountID; self.request = request
        connection = nil; problem = nil; busy = false
    }
    func refresh() async { await perform("GET") }
    func start() async { await perform("POST") }
    func disconnect() async { await perform("DELETE") }
    private func perform(_ method: String) async {
        guard !busy, accountID != nil, let request else { return }
        let generation = generation
        busy = true
        defer { if generation == self.generation { busy = false } }
        do {
            let result = try await request(method)
            guard generation == self.generation else { return }
            connection = result; problem = result.error
        } catch {
            guard generation == self.generation, !(error is CancellationError) else { return }
            problem = error.localizedDescription
        }
    }
    func poll() async {
        let generation = generation
        while pending && generation == self.generation && !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            await refresh()
        }
    }
    var verificationURL: URL? {
        guard let raw = connection?.verificationUrl, let url = URL(string: raw),
              url.scheme == "https", url.host == "auth.openai.com", url.path == "/codex/device",
              url.user == nil, url.password == nil, url.port == nil else { return nil }
        return url
    }
}

struct ChatGPTConnectionPanel: View {
    @Bindable var model: ChatGPTConnectionModel
    @State private var browser: BrowserDestination?
    @Environment(\.scenePhase) private var scenePhase
    private struct BrowserDestination: Identifiable { let id = UUID(); let url: URL }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.canChat {
                Label("ChatGPT подключён", systemImage: "checkmark.circle")
                    .font(.headline).accessibilityIdentifier("chatgpt.connected")
                if let email = model.connection?.email { Text(email).font(.subheadline).foregroundStyle(.secondary) }
                if model.connection?.managed == true {
                    Button("Отключить ChatGPT", role: .destructive) { Task { await model.disconnect() } }
                        .frame(minHeight: 44).disabled(model.busy).accessibilityIdentifier("chatgpt.disconnect")
                }
            } else if model.pending {
                Text("Подтвердите вход в ChatGPT").font(.title3.weight(.semibold))
                if let code = model.connection?.userCode {
                    Text(code).font(.title2.monospaced().weight(.semibold)).textSelection(.enabled)
                        .accessibilityIdentifier("chatgpt.code")
                }
                Text("Вставьте этот код в ChatGPT. После подтверждения чат откроется автоматически.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Скопировать код и открыть ChatGPT", action: openChatGPT)
                    .buttonStyle(.borderedProminent).tint(.primary).controlSize(.large)
                    .disabled(model.verificationURL == nil).accessibilityIdentifier("chatgpt.open")
                Button("Отменить подключение") { Task { await model.disconnect() } }
                    .frame(minHeight: 44).disabled(model.busy).accessibilityIdentifier("chatgpt.cancel")
            } else {
                Text("Подключите свой ChatGPT").font(.title3.weight(.semibold))
                Text("Один вход — и можно писать, отправлять фото и работать со своими данными. Ответы используют лимиты вашего ChatGPT.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button {
                    Task { await model.start(); if model.pending { openChatGPT() } }
                } label: {
                    HStack { if model.busy { ProgressView() }; Text("Подключить ChatGPT") }
                        .frame(maxWidth: .infinity, minHeight: 32)
                }.buttonStyle(.borderedProminent).tint(.primary).controlSize(.large)
                    .disabled(model.busy).accessibilityIdentifier("chatgpt.connect")
            }
            if let problem = model.problem {
                Text(problem).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("chatgpt.error")
                if model.connection == nil {
                    Button("Проверить подключение") { Task { await model.refresh() } }.frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: 480, alignment: .leading).padding(24)
        .task(id: model.pending) { if model.pending { await model.poll() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
        .onChange(of: model.canChat) { _, connected in if connected { browser = nil } }
        .sheet(item: $browser) { destination in ChatGPTBrowser(url: destination.url).ignoresSafeArea() }
    }
    private func openChatGPT() {
        guard let url = model.verificationURL, let code = model.connection?.userCode else { return }
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: code]], options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)])
        browser = BrowserDestination(url: url)
    }
}

private struct ChatGPTBrowser: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct ChatGPTConnectionSheet: View {
    @Bindable var model: ChatGPTConnectionModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { ChatGPTConnectionPanel(model: model) }
                .navigationTitle("ChatGPT").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
        }.tint(.primary).task { await model.refresh() }
    }
}
