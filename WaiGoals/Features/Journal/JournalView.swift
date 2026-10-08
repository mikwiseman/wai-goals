import SwiftUI
import SwiftData

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]
    @State private var weekly = false
    @State private var date = Date()
    @State private var editing: JournalKind?
    @State private var analyzingID: UUID?
    @State private var error: String?
    private var kinds: [JournalKind] { weekly ? [.weekPlan, .weekReview] : [.dayPlan, .dayReview] }
    private func entry(_ kind: JournalKind) -> JournalEntry? { entries.first { $0.kind == kind && $0.periodKey == kind.periodKey(for:date) } }
    private var periodTitle: String {
        let start = kinds[0].start(for:date)
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Locale(identifier:"ru_RU"))
        if weekly, let end = Calendar.current.date(byAdding:.day, value:6, to:start) { return "\(start.formatted(format)) — \(end.formatted(format))" }
        return start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier:"ru_RU")))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading, spacing:28) {
                    Picker("Период", selection:$weekly) { Text("День").tag(false); Text("Неделя").tag(true) }.pickerStyle(.segmented)
                    VStack(alignment:.leading, spacing:12) {
                        Text(periodTitle).font(.title2.weight(.semibold)).accessibilityIdentifier("journal.period")
                        HStack {
                            Button { shift(-1) } label: { Image(systemName:"chevron.left").frame(width:44,height:44) }.accessibilityLabel("Предыдущий период")
                            DatePicker("Дата", selection:$date, displayedComponents:.date).labelsHidden().environment(\.locale, Locale(identifier:"ru_RU"))
                            Button { shift(1) } label: { Image(systemName:"chevron.right").frame(width:44,height:44) }.accessibilityLabel("Следующий период")
                            Spacer(minLength:0)
                            Button("Сегодня") { date = .now }.font(.subheadline)
                        }
                    }
                    ForEach(kinds) { kind in
                        section(kind)
                        Divider()
                    }
                    if let error { Text(error).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("journal.error") }
                    Text("Планы и итоги сохраняются на устройстве и синхронизируются с личным аккаунтом. Прошлые записи доступны через дату.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Дневник")
            .sheet(item:$editing) { kind in JournalEditorView(kind:kind,date:date,initialText:entry(kind)?.text ?? "") }
        }
    }
    @ViewBuilder private func section(_ kind: JournalKind) -> some View {
        let row = entry(kind)
        VStack(alignment:.leading, spacing:16) {
            HStack(alignment:.firstTextBaseline) {
                Text(kind.title).font(.title3.weight(.semibold))
                Spacer(minLength:12)
                if row != nil {
                    Button("Изменить") { editing = kind }.font(.subheadline).disabled(analyzingID == row?.id)
                        .accessibilityLabel("Изменить: \(kind.title)")
                }
            }
            if let row {
                Text(row.text).font(.body).lineSpacing(5).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                if let insight = row.insight {
                    VStack(alignment:.leading,spacing:8) {
                        Label("Взгляд со стороны",systemImage:"sparkle").font(.subheadline.weight(.semibold))
                        Text(insight).font(.subheadline).lineSpacing(4).textSelection(.enabled)
                    }
                    .padding(.leading,16)
                    .overlay(alignment:.leading) { RoundedRectangle(cornerRadius:2).fill(Color.accentColor).frame(width:3) }
                }
                Button { analyze(row) } label: {
                    HStack(spacing:8) {
                        if analyzingID == row.id { ProgressView() }
                        else { Image(systemName:"sparkle") }
                        Text(analyzingID == row.id ? "Разбираю запись…" : row.insight == nil ? "Разобрать с Codex" : "Обновить разбор")
                    }.frame(minHeight:44)
                }.disabled(analyzingID != nil).accessibilityIdentifier("journal.reflect.\(kind.rawValue)")
            } else {
                Text(kind.prompt).foregroundStyle(.secondary).lineSpacing(4)
                Button { editing = kind } label: {
                    Label("Надиктовать или написать",systemImage:"mic.fill").frame(minHeight:44)
                }.accessibilityIdentifier("journal.add.\(kind.rawValue)")
            }
        }
    }
    private func shift(_ direction: Int) { date = Calendar.current.date(byAdding:.day,value:direction * (weekly ? 7 : 1),to:date) ?? date }
    private func analyze(_ row: JournalEntry) {
        guard analyzingID == nil else { return }
        analyzingID = row.id; error = nil
        let submitted = row.text
        Task { @MainActor in
            defer { analyzingID = nil }
            do {
                let insight = try await GoalsConnection.shared.reflect(entry:row)
                guard row.text == submitted else { error = "Запись изменилась. Запусти разбор ещё раз."; return }
                let old = row.insight
                row.insight = insight
                do { try context.save() } catch { row.insight = old; throw error }
                NotificationCenter.default.post(name:.goalsDidSave,object:nil)
            } catch { self.error = "Разбор не завершён. Твоя запись сохранена. Попробуй ещё раз, когда появится связь." }
        }
    }
}

struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    let kind: JournalKind
    let date: Date
    private let draftKey: String
    @State private var text: String
    @State private var recorder: JournalRecorder
    @State private var transcribing = false
    @State private var error: String?
    @State private var visible = false
    @State private var transcription: Task<Void,Never>?

    init(kind:JournalKind,date:Date,initialText:String) {
        self.kind = kind; self.date = date
        let id = kind.rawValue + "." + kind.periodKey(for:date)
        draftKey = "journal.draft." + id
        _text = State(initialValue:UserDefaults.standard.string(forKey:draftKey) ?? initialText)
        _recorder = State(initialValue:JournalRecorder(draftID:id))
    }
    var body: some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:18) {
                Text(kind.prompt).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                TextEditor(text:$text)
                    .font(.body).scrollContentBackground(.hidden).padding(10)
                    .background(Color(.secondarySystemBackground),in:RoundedRectangle(cornerRadius:18))
                    .accessibilityLabel(kind.title).accessibilityIdentifier("journal.editor")
                if transcribing {
                    HStack { ProgressView(); Text("Распознаю запись…") }.font(.subheadline)
                } else if recorder.hasRecording {
                    HStack {
                        Button("Распознать ещё раз") { transcribe() }.frame(minHeight:44)
                        Spacer()
                        Button(role:.destructive) { recorder.clear() } label: { Image(systemName:"trash").frame(width:44,height:44) }.accessibilityLabel("Удалить аудиочерновик")
                    }
                } else {
                    Button {
                        if recorder.isRecording { recorder.stop() }
                        else { Task { await recorder.start() } }
                    } label: {
                        Label(recorder.isRecording ? "Остановить запись" : "Надиктовать",systemImage:recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                            .font(.headline).frame(maxWidth:.infinity,minHeight:48)
                    }
                    .buttonStyle(.bordered).tint(recorder.isRecording ? .red : .accentColor)
                    .disabled(recorder.permissionPending).accessibilityIdentifier("journal.record")
                    if recorder.isRecording { Text("Записываю… До 5 минут. Текст появится после остановки.").font(.caption).foregroundStyle(.secondary) }
                }
                if let message = error ?? recorder.error { Text(message).font(.footnote).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true) }
                if recorder.hasRecording && !transcribing { Text("Аудиочерновик сохранён на устройстве. Можно вернуться к нему позже.").font(.caption).foregroundStyle(.secondary) }
                Button("Сохранить") { save() }
                    .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth:.infinity)
                    .disabled(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || recorder.isRecording || transcribing || recorder.hasRecording)
                    .accessibilityIdentifier("journal.save")
            }
            .padding(24)
            .navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Закрыть") { dismiss() } } }
            .task { visible = true; if recorder.hasRecording { transcribe() } }
            .onChange(of:text) { _,value in UserDefaults.standard.set(value,forKey:draftKey) }
            .onChange(of:recorder.hasRecording) { _,ready in if ready && visible { transcribe() } }
            .onChange(of:phase) { _,value in if value == .background { recorder.pause() } }
            .onDisappear { visible = false; transcription?.cancel(); recorder.pause() }
        }
    }
    private func transcribe() {
        guard !transcribing else { return }
        transcribing = true; error = nil
        transcription = Task { @MainActor in
            defer { transcribing = false }
            do {
                let addition = try await GoalsConnection.shared.transcribe(audio:recorder.audio())
                try Task.checkCancellation()
                text = text.trimmingCharacters(in:.whitespacesAndNewlines)
                text += (text.isEmpty ? "" : "\n\n") + addition
                UserDefaults.standard.set(text,forKey:draftKey)
                recorder.clear()
            } catch is CancellationError { }
            catch { if !Task.isCancelled { self.error = "Не удалось распознать речь. Аудиочерновик сохранён. Попробуй ещё раз при доступной связи." } }
        }
    }
    private func save() {
        do {
            try JournalEntry.save(kind:kind,date:date,text:text,context:context)
            UserDefaults.standard.removeObject(forKey:draftKey)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
