import SwiftUI
import AVFoundation

/// Text, dictation and voice are three ways into the same conversation.
struct ConversationComposer<Attachments: View, Preview: View>: View {
    @Binding var draft: String
    @Bindable var voice: ConversationVoice
    var busy: Bool
    var hasAttachments = false
    var allowsAttachments = true
    var placeholder = "Сообщение"
    var send: () -> Void
    @ViewBuilder var attachments: () -> Attachments
    @ViewBuilder var preview: () -> Preview
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasContent: Bool { hasAttachments || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var dictating: Bool { !voice.live && (voice.phase != .idle || voice.permissionPending) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if voice.live {
                livePanel
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    preview()
                    ZStack(alignment: .leading) {
                        TextField(placeholder, text: $draft, axis: .vertical)
                            .font(.body)
                            .lineLimit(1...6)
                            .focused($focused)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 6)
                            .opacity(dictating ? 0 : 1)
                            .accessibilityHidden(dictating)
                            .disabled(busy || dictating)
                            .accessibilityLabel("Сообщение")
                            .accessibilityIdentifier("conversation.composer")
                        if dictating { dictationPanel.padding(.horizontal, 12) }
                    }
                    HStack(spacing: 8) {
                        if allowsAttachments {
                            Menu(content: attachments) {
                                Image(systemName: "plus").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Добавить вложение")
                            .accessibilityIdentifier("conversation.attach")
                            .disabled(busy || dictating)
                        }
                        Spacer(minLength: 0)
                        Button { voice.toggleDictation() } label: {
                            Image(systemName: voice.isRecording ? "stop.fill" : "mic")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(voice.isRecording ? "Закончить диктовку" : "Надиктовать")
                        .accessibilityHint("Речь добавляется в черновик. Отправка отдельной кнопкой.")
                        .accessibilityIdentifier("conversation.dictation")
                        .disabled(busy || voice.permissionPending || voice.phase == .transcribing)

                        Button {
                            focused = false
                            if hasContent { send() } else { voice.toggleLive() }
                        } label: {
                            Image(systemName: hasContent ? "arrow.up" : "waveform")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .background(Color.primary, in: Circle())
                        }
                        .accessibilityLabel(hasContent ? "Отправить" : "Начать голосовой разговор")
                        .accessibilityIdentifier(hasContent ? "conversation.send" : "conversation.live")
                        .disabled(busy || dictating)
                    }
                    .font(.system(size: 20, weight: .medium))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
                .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.primary.opacity(0.06)))
            }

            if let error = voice.error {
                Text(error).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if voice.hasDraft && voice.phase == .idle && !busy {
                HStack {
                    Button("Распознать запись") { voice.retryDraft() }
                    Spacer()
                    Button { voice.discardDraft() } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }.accessibilityLabel("Удалить сохранённую запись")
                }.font(.subheadline)
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in voice.suspend() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { notification in
            if let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
               raw == AVAudioSession.InterruptionType.began.rawValue { voice.suspend() }
        }
    }

    private var dictationPanel: some View {
        HStack(spacing: 12) {
            if voice.isRecording { ConversationWave(level: voice.level) }
            else { ProgressView() }
            Text(voice.permissionPending ? "Включаю микрофон…" : voice.status)
                .font(.subheadline).monospacedDigit()
            Spacer(minLength: 0)
            Button { voice.cancelDictation() } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }.accessibilityLabel("Отменить диктовку")
        }.frame(minHeight: 48)
    }

    private var livePanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { liveStatus; Spacer(minLength: 4); liveActions }
            VStack(alignment: .leading, spacing: 12) { liveStatus; HStack { Spacer(); liveActions } }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 26))
        .accessibilityIdentifier("conversation.livePanel")
    }

    private var liveStatus: some View {
        HStack(spacing: 12) {
            ConversationWave(level: voice.level)
            Text(voice.permissionPending ? "Включаю микрофон…" : voice.status)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var liveActions: some View {
        HStack(spacing: 8) {
            if voice.phase == .speaking {
                Button { voice.interruptPlayback() } label: {
                    Image(systemName: "stop.fill").frame(width: 44, height: 44)
                }.accessibilityLabel("Перебить и говорить")
            }
            Button { voice.suspend() } label: {
                Label("К тексту", systemImage: "keyboard")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }.accessibilityIdentifier("conversation.endLive")
        }.buttonStyle(.plain)
    }
}

struct ConversationWave: View {
    var level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                Capsule().frame(width: 3, height: reduceMotion ? 8 : 4 + max(0, min(1, level)) * [12, 22, 30, 22, 12][index])
            }
        }.frame(width: 32, height: 34)
            .animation(reduceMotion ? nil : .linear(duration: 0.1), value: level)
            .accessibilityHidden(true)
    }
}

struct ConversationWelcome: View {
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.largeTitle.weight(.semibold)).tracking(-0.6)
            Text(subtitle).font(.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 44)
    }
}

struct ConversationProgress: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Думаю…").font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            .accessibilityElement(children: .combine)
    }
}

struct ConversationPhotoPreview: View {
    var data: Data
    var remove: () -> Void
    var body: some View {
        if let image = UIImage(data: data) {
            HStack(spacing: 12) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Фото").font(.subheadline)
                Spacer()
                Button(action: remove) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("Убрать фото")
            }.padding(12)
        }
    }
}

func conversationPhotoData(_ data: Data) -> Data? {
    guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
    let scale = min(1, 1600 / max(image.size.width, image.size.height))
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let imageData = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
    guard let imageData, imageData.count <= 2_000_000 else { return nil }
    return imageData
}

struct ConversationMessage: View {
    var text: String
    var isUser: Bool
    var images: [Data] = []
    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 10) {
                ForEach(images.indices, id: \.self) { index in
                    if let image = UIImage(data: images[index]) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: 240, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .accessibilityLabel("Отправленное фото")
                    }
                }
                Text(.init(text)).font(.body).textSelection(.enabled)
                    .padding(isUser ? 14 : 0)
                    .background(isUser ? Color(uiColor: .secondarySystemBackground) : .clear,
                                in: RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: isUser ? nil : .infinity, alignment: .leading)
            }
        }.frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
