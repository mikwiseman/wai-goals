import SwiftUI
import PhotosUI
import SwiftData

struct GoalsConversationView: View {
    @Environment(\.modelContext) private var context
    @State private var conversation = Conversation(name: GoalsConnection.shared.conversationName)
    @State private var chatGPT = ChatGPTConnectionModel()
    @State private var chatGPTShown = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var voice = ConversationVoice()
    @State private var busy = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photosShown = false
    @State private var readingPhoto = false
    @State private var problem: String?
    @State private var historyShown = false
    @State private var settingsShown = false
    private var connection: GoalsConnection { .shared }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ConversationTimeline(revision: conversation.lines.count, sending: busy) {
                    if chatGPT.canChat && conversation.lines.isEmpty {
                        ConversationWelcome(title: "Что хочешь сделать?", subtitle: "Планы, цели и итоги дня.")
                    }
                    if !chatGPT.canChat { ChatGPTConnectionPanel(model: chatGPT) }
                    ForEach(conversation.lines) { line in
                        ConversationMessage(text: line.text, isUser: line.role == "user", images: line.images ?? []).id(line.id)
                    }
                    if busy && !voice.live { ConversationProgress() }
                }
                if let error = problem ?? conversation.storageError { Text(error).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16) }
            }
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ConversationComposer(draft: $conversation.draft, voice: voice, busy: busy || readingPhoto, retrying: conversation.canRetry(context: conversation.pending?.context ?? TimeZone.current.identifier),
                                     hasAttachments: !conversation.photos.isEmpty, allowsVoice: chatGPT.canUseVoice, allowsSend: chatGPT.canChat, send: send, pasteImages: pastePhotos) {
                    Button("Фото", systemImage: "photo") { photosShown = true }
                } preview: {
                    if let data = conversation.photos.first {
                        ConversationPhotoPreview(data: data) { conversation.photos = []; try? conversation.save() }.disabled(busy)
                    }
                }
            }
            .navigationTitle("Codex").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("ChatGPT", systemImage: "bubble.left") { voice.suspend(); chatGPTShown = true }
                        Button("Дневник", systemImage: "book.closed") { voice.suspend(); historyShown = true }
                        Button("Настройки", systemImage: "gearshape") { voice.suspend(); settingsShown = true }
                    } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("Настройки чата").accessibilityIdentifier("conversation.settings")
                }
            }
            .sheet(isPresented: $chatGPTShown) { ChatGPTConnectionSheet(model: chatGPT) }
            .sheet(isPresented: $historyShown) { JournalView() }
            .sheet(isPresented: $settingsShown) { SettingsView() }
            .photosPicker(isPresented: $photosShown, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                readingPhoto = true
                Task {
                    defer { photoItem = nil; readingPhoto = false }
                    guard let raw = try? await item.loadTransferable(type: Data.self), let image = conversationPhotoData(raw) else {
                        problem = "Не удалось прочитать фото. Попробуй другое."; return
                    }
                    conversation.photos = [image]
                    do { try conversation.save() } catch { problem = "Не удалось сохранить фото." }
                }
            }
            .onAppear {
                voice.transcribe = { try await connection.transcribe(audio: $0) }
                voice.synthesize = { try await connection.speech($0) }
                voice.receive = { text, live in conversation.draft += (conversation.draft.isEmpty ? "" : " ") + text; try conversation.save(); if live { send() } }
            }
            .onDisappear { voice.suspend(); try? conversation.save() }
            .onChange(of: conversation.draft) { _, _ in try? conversation.save() }
        }.tint(.primary)
        .task(id: connection.accountIdentifier) {
            let accountID = connection.accountIdentifier
            chatGPT.configure(accountID: accountID) { method in
                guard connection.accountIdentifier == accountID else { throw CancellationError() }
                return try await connection.chatGPTConnection(method: method)
            }
            await chatGPT.refresh()
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await chatGPT.refresh() } } }
        .onChange(of: problem) { _, value in if value != nil { Task { await chatGPT.refresh() } } }
    }
    private func pastePhotos(_ images: [Data]) {
        guard !busy, let raw = images.first, let image = conversationPhotoData(raw) else { return }
        conversation.photos = [image]
        try? conversation.save()
    }

    private func send() {
        let draft = conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = draft.isEmpty && !conversation.photos.isEmpty ? "Что на этом фото?" : draft
        guard chatGPT.canChat, !busy, !readingPhoto, !voice.isRecording, !text.isEmpty || !conversation.photos.isEmpty else { return }
        busy = true; problem = nil
        Task {
            defer { busy = false }
            do {
                let payload: [String: Any] = ["text": text, "timezone": TimeZone.current.identifier, "history": conversation.history, "images": conversation.photos.map { "data:image/jpeg;base64," + $0.base64EncodedString() }]
                let command = try conversation.prepare(text: text, context: conversation.pending?.text == text ? conversation.pending!.context : TimeZone.current.identifier, body: JSONSerialization.data(withJSONObject: payload, options: .sortedKeys), images: conversation.photos)
                let answer = try await connection.message(command)
                var reply = answer.reply
                if let entry = answer.journal {
                    let format = DateFormatter(); format.calendar = Calendar(identifier: .gregorian); format.locale = Locale(identifier: "en_US_POSIX"); format.timeZone = .current; format.dateFormat = "yyyy-MM-dd"; format.isLenient = false
                    guard let day = format.date(from: entry.period), format.string(from: day) == entry.period, entry.kind.periodKey(for: day) == entry.period else { throw CocoaError(.coderInvalidValue) }
                    try JournalEntry.save(kind: entry.kind, date: day, text: entry.text, context: context)
                    reply += "\n\nСохранено: " + entry.kind.title + " · " + entry.period
                    await connection.sync(goals: context.allGoals(), journal: context.allJournalEntries())
                }
                try conversation.complete(reply)
                await voice.readReply(reply)
            } catch {
                problem = "Ответ не получен. Черновик сохранён. Можно повторить запрос."
                voice.suspend()
            }
        }
    }
}
