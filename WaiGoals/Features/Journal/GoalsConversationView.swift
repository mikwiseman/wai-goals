import SwiftUI
import PhotosUI
import SwiftData

struct GoalsConversationView: View {
    @Environment(\.modelContext) private var context
    @State private var conversation = Conversation(name: "goals-conversation")
    @State private var voice = ConversationVoice()
    @State private var busy = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photosShown = false
    @State private var readingPhoto = false
    @State private var problem: String?
    @State private var historyShown = false
    @State private var settingsShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onOpenWorkspace: (() -> Void)?
    private var connection: GoalsConnection { .shared }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if conversation.lines.isEmpty {
                                ConversationWelcome(title: "Что для тебя сейчас важно?", subtitle: "Планы, итоги и движение к твоим целям.")
                            }
                            if connection.aiAvailable == false {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("В этом аккаунте AI пока не подключён. Цели и дневник уже доступны.")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    if let onOpenWorkspace {
                                        Button("Открыть цели", action: onOpenWorkspace).frame(minHeight: 44)
                                    }
                                }
                            }
                            ForEach(conversation.lines) { line in
                                ConversationMessage(text: line.text, isUser: line.role == "user", images: line.images ?? []).id(line.id)
                            }
                            if busy && !voice.live { ConversationProgress() }
                            Color.clear.frame(height: 1).id("bottom")
                        }.frame(maxWidth: 720).padding(.horizontal, 24).padding(.vertical, 16).frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: conversation.lines.count) { _, _ in
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                if let error = problem ?? conversation.storageError { Text(error).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16) }
            }
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ConversationComposer(draft: $conversation.draft, voice: voice, busy: busy || readingPhoto,
                                     hasAttachments: !conversation.photos.isEmpty, send: send) {
                    Button("Фото", systemImage: "photo") { photosShown = true }
                } preview: {
                    if let data = conversation.photos.first {
                        ConversationPhotoPreview(data: data) { conversation.photos = []; try? conversation.save() }.disabled(busy)
                    }
                }
                .disabled(connection.aiAvailable == false)
            }
            .navigationTitle("Goals").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let onOpenWorkspace { Button("Цели и прогресс", systemImage: "scope") { voice.suspend(); onOpenWorkspace() } }
                        Button("Дневник", systemImage: "book.closed") { voice.suspend(); historyShown = true }
                        Button("Настройки", systemImage: "gearshape") { voice.suspend(); settingsShown = true }
                    } label: { Image(systemName: "square.grid.2x2") }
                        .accessibilityLabel("Цели, дневник и настройки").accessibilityIdentifier("conversation.workspace")
                }
            }
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
    }
    private func send() {
        let draft = conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = draft.isEmpty && !conversation.photos.isEmpty ? "Что на этом фото?" : draft
        guard !busy, !readingPhoto, !voice.isRecording, !text.isEmpty || !conversation.photos.isEmpty else { return }
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
                problem = "Ответ не завершён. Черновик сохранён; повтор использует тот же запрос."
                voice.pause("Голос приостановлен. Можно продолжить текстом.")
            }
        }
    }
}
