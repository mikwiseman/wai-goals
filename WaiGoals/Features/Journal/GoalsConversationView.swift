import SwiftUI
import SwiftData

struct GoalsConversationView: View {
    @Environment(\.modelContext) private var context
    @State private var conversation = Conversation(name: "goals-conversation")
    @State private var voice = ConversationVoice()
    @State private var busy = false
    @State private var problem: String?
    @State private var historyShown = false
    private var connection: GoalsConnection { .shared }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            if conversation.lines.isEmpty {
                                Text("Что для тебя\nсейчас важно?").font(.largeTitle.weight(.semibold)).padding(.top, 32)
                                Text("Планы, итоги и размышления о том, куда уходят время и силы.").foregroundStyle(.secondary)
                                ForEach(JournalKind.allCases) { kind in
                                    Button(kind.title) { conversation.draft = kind.title + ": " }.buttonStyle(.bordered)
                                }
                            }
                            ForEach(conversation.lines) { line in
                                Text(.init(line.text)).textSelection(.enabled)
                                    .padding(line.role == "user" ? 14 : 0)
                                    .background(line.role == "user" ? Color(.secondarySystemBackground) : .clear, in: RoundedRectangle(cornerRadius: 18))
                                    .frame(maxWidth: .infinity, alignment: line.role == "user" ? .trailing : .leading)
                            }
                            if busy { ProgressView("Разбираю запись…") }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(20)
                    }.onChange(of: conversation.lines.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                if let error = problem ?? conversation.storageError { Text(error).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16) }
                ConversationVoiceControls(voice: voice, busy: busy)
                HStack(spacing: 12) {
                    TextField("Сообщение", text: $conversation.draft, axis: .vertical).lineLimit(1...6).padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
                    if conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { voice.toggleDictation() } label: { Image(systemName: voice.isRecording ? "stop.circle.fill" : "mic").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel("Диктовка")
                    } else {
                        Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.largeTitle).frame(width: 44, height: 44) }.accessibilityLabel("Отправить")
                    }
                }.padding(.horizontal, 16).padding(.bottom, 12).disabled(busy || voice.live)
            }
            .navigationTitle("Wai Goals").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { historyShown = true } label: { Image(systemName: "book.closed") }.accessibilityLabel("Дневник и история") } }
            .sheet(isPresented: $historyShown) { JournalView() }
            .onAppear {
                voice.transcribe = { try await connection.transcribe(audio: $0) }
                voice.synthesize = { try await connection.speech($0) }
                voice.receive = { text, live in conversation.draft += (conversation.draft.isEmpty ? "" : " ") + text; try conversation.save(); if live { send() } }
            }
            .onDisappear { voice.suspend(); try? conversation.save() }
            .onChange(of: conversation.draft) { _, _ in try? conversation.save() }
        }
    }
    private func send() {
        let text = conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !voice.isRecording, !text.isEmpty else { return }
        busy = true; problem = nil
        Task {
            defer { busy = false }
            do {
                let payload: [String: Any] = ["text": text, "timezone": TimeZone.current.identifier, "history": conversation.history]
                let command = try conversation.prepare(text: text, context: conversation.pending?.text == text ? conversation.pending!.context : TimeZone.current.identifier, body: JSONSerialization.data(withJSONObject: payload, options: .sortedKeys))
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
