import SwiftUI
import AVFoundation
import UIKit

/// Text, dictation and voice are three ways into the same conversation.
struct ConversationComposer<Attachments: View, Preview: View>: View {
    @Binding var draft: String
    @Bindable var voice: ConversationVoice
    var busy: Bool
    var retrying = false
    var hasAttachments = false
    var allowsAttachments = true
    var allowsVoice = true
    var allowsSend = true
    var placeholder = "Сообщение"
    var send: () -> Void
    var pasteImages: (([Data]) -> Void)? = nil
    @ViewBuilder var attachments: () -> Attachments
    @ViewBuilder var preview: () -> Preview
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasContent: Bool { hasAttachments || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var dictating: Bool { !voice.live && (voice.phase != .idle || voice.permissionPending) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if voice.live {
                livePanel
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if !busy { preview() }
                    if dictating {
                        dictationPanel.padding(.horizontal, 8)
                    } else if dynamicTypeSize.isAccessibilitySize {
                        editor.padding(.horizontal, 12)
                        HStack(spacing: 0) { addButton; Spacer(minLength: 8); microphone; sendButton }
                    } else {
                        HStack(alignment: .bottom, spacing: 0) {
                            addButton
                            editor
                            microphone
                            sendButton
                        }
                    }
                }
                .padding(4)
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

    private var editor: some View {
        ZStack(alignment: .leading) {
            if busy || draft.isEmpty {
                Text(busy ? "Жду ответ…" : placeholder)
                    .font(.body).foregroundStyle(.secondary).allowsHitTesting(false)
            }
            ConversationTextInput(text: Binding(get: { busy ? "" : draft }, set: { if !busy { draft = $0 } }),
                                  enabled: !busy && isEnabled, pasteImages: pasteImages)
                .frame(minHeight: 44)
        }.frame(maxWidth: .infinity)
    }

    @ViewBuilder private var addButton: some View {
        if allowsAttachments {
            Menu {
                attachments()
                if allowsVoice { Button("Голосовой разговор", systemImage: "waveform") { dismissKeyboard(); voice.toggleLive() } }
            } label: {
                Image(systemName: "plus").font(.system(size: 20)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Добавить фото или открыть голосовой режим")
            .accessibilityIdentifier("conversation.attach")
            .disabled(busy)
        }
    }

    @ViewBuilder private var microphone: some View {
        if allowsVoice { Button { dismissKeyboard(); voice.toggleDictation() } label: {
            Image(systemName: "mic").font(.system(size: 19)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Надиктовать")
        .accessibilityHint("Речь добавится в черновик.")
        .accessibilityIdentifier("conversation.dictation")
        .disabled(busy || voice.permissionPending) }
    }

    private var sendButton: some View {
        Button {
            dismissKeyboard()
            if hasContent { send() } else if allowsVoice { voice.toggleLive() }
        } label: {
            Image(systemName: busy ? "ellipsis" : hasContent ? (retrying ? "arrow.clockwise" : "arrow.up") : (allowsVoice ? "waveform" : "arrow.up"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(width: 36, height: 36)
                .background(Color.primary, in: Circle())
                .frame(width: 44, height: 44)
        }.buttonStyle(.plain)
            .accessibilityLabel(busy ? "Жду ответ" : hasContent ? (retrying ? "Повторить запрос" : "Отправить") : (allowsVoice ? "Начать голосовой разговор" : "Отправить"))
            .accessibilityIdentifier(hasContent || !allowsVoice ? "conversation.send" : "conversation.live")
            .disabled(busy || !allowsSend || (!hasContent && !allowsVoice))
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var dictationPanel: some View {
        HStack(spacing: 12) {
            if voice.isRecording { ConversationWave(level: voice.level) }
            else { ProgressView() }
            Text(voice.permissionPending ? "Включаю микрофон…" : voice.status)
                .font(.subheadline).monospacedDigit()
            Spacer(minLength: 0)
            if voice.isRecording {
                Button { voice.toggleDictation() } label: {
                    Image(systemName: "checkmark").frame(width: 44, height: 44)
                }.accessibilityLabel("Закончить диктовку")
            }
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
        VStack(spacing: 8) {
            Text(title).font(.title3.weight(.medium))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.vertical, 36)
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
            HStack {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button(action: remove) {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.primary, Color(uiColor: .systemBackground))
                            .frame(width: 44, height: 44)
                    }.offset(x: 12, y: -12).accessibilityLabel("Убрать фото")
                }
                Spacer()
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
                Text(conversationText(text, isUser: isUser)).font(.body).textSelection(.enabled)
                    .padding(isUser ? 14 : 0)
                    .background(isUser ? Color(uiColor: .secondarySystemBackground) : .clear,
                                in: RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: isUser ? nil : .infinity, alignment: .leading)
            }
        }.frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

/// User input is data, including literal Markdown and code. Replies retain inline
/// formatting without collapsing paragraphs or line breaks.
func conversationText(_ text: String, isUser: Bool) -> AttributedString {
    if isUser { return AttributedString(text) }
    return (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
}

/// Follow new answers until the reader deliberately moves away from the bottom.
struct ConversationTimeline<Revision: Equatable, Content: View>: View {
    var revision: Revision
    var sending: Bool
    @ViewBuilder var content: () -> Content
    @State private var position = ConversationReadingPosition()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    content()
                    Color.clear.frame(height: 1).id("conversation.bottom")
                }.frame(maxWidth: 720).padding(.horizontal, 24).padding(.vertical, 16).frame(maxWidth: .infinity)
            }
            .conversationInitialScroll()
            .scrollDismissesKeyboard(.interactively)
            .modifier(ConversationReadingTracker(position: $position))
            .overlay(alignment: .bottomTrailing) {
                if !position.followsLatest {
                    Button {
                        position = ConversationReadingPosition()
                        scroll(proxy)
                    } label: {
                        Image(systemName: "arrow.down").font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08)))
                    }.buttonStyle(.plain).padding(16)
                        .accessibilityLabel("К последнему сообщению")
                        .accessibilityIdentifier("conversation.latest")
                }
            }
            .onChange(of: revision) { _, _ in if position.shouldFollow { scroll(proxy) } }
            .onChange(of: sending) { _, active in
                if active { position = ConversationReadingPosition() }
                if position.shouldFollow { scroll(proxy) }
            }
            .onAppear { proxy.scrollTo("conversation.bottom", anchor: .bottom) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            proxy.scrollTo("conversation.bottom", anchor: .bottom)
        }
    }
}

struct ConversationReadingPosition {
    var followsLatest = true
    var interacting = false
    var shouldFollow: Bool { followsLatest && !interacting }

    mutating func userMoved(nearBottom: Bool) {
        if interacting { followsLatest = nearBottom }
    }
}

private struct ConversationReadingTracker: ViewModifier {
    @Binding var position: ConversationReadingPosition
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 80
                } action: { _, nearBottom in
                    position.userMoved(nearBottom: nearBottom)
                }
                .onScrollPhaseChange { _, phase, context in
                    switch phase {
                    case .tracking, .interacting, .decelerating:
                        position.interacting = true
                    case .idle:
                        if position.interacting {
                            let geometry = context.geometry
                            position.userMoved(nearBottom: geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height < 80)
                        }
                        position.interacting = false
                    default: break
                    }
                }
        } else { content }
    }
}

/// Native editing preserves newlines/code and supports an explicit Paste image action.
struct ConversationTextInput: UIViewRepresentable {
    @Binding var text: String
    var enabled: Bool
    var pasteImages: (([Data]) -> Void)?

    func makeUIView(context: Context) -> ConversationPasteView {
        let view = ConversationPasteView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .label
        view.textContainerInset = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        // Preserve typed code, commands, quotes, and spacing exactly.
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.isScrollEnabled = false
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = "conversation.composer"
        view.accessibilityLabel = "Сообщение"
        return view
    }
    func updateUIView(_ view: ConversationPasteView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        view.isEditable = enabled
        view.pasteImages = enabled ? pasteImages : nil
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ConversationPasteView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let maximum = (uiView.font?.lineHeight ?? 22) * 5 + 22
        uiView.isScrollEnabled = height > maximum
        return CGSize(width: width, height: max(44, min(height, maximum)))
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ConversationTextInput
        init(_ parent: ConversationTextInput) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text; textView.invalidateIntrinsicContentSize() }
    }
}
final class ConversationPasteView: UITextView {
    var pasteImages: (([Data]) -> Void)?
    var imagePasteboard: UIPasteboard = .general
    override func paste(_ sender: Any?) {
        if let pasteImages, imagePasteboard.hasImages {
            let images = (imagePasteboard.images ?? []).compactMap { $0.jpegData(compressionQuality: 0.9) }
            if !images.isEmpty { pasteImages(images); return }
        }
        super.paste(sender)
    }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), pasteImages != nil, imagePasteboard.hasImages { return true }
        return super.canPerformAction(action, withSender: sender)
    }
}

// iOS 17 keeps its original fallback; newer OS versions align short threads naturally.
extension View {
    @ViewBuilder func conversationInitialScroll() -> some View {
        if #available(iOS 18.0, *) { self.defaultScrollAnchor(.bottom).defaultScrollAnchor(.top, for: .alignment) }
        else { self.defaultScrollAnchor(.bottom) }
    }
}
