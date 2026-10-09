import SwiftUI
@preconcurrency import AVFoundation

/// One microphone owner. Dictation edits the draft; live mode takes spoken turns.
@MainActor @Observable
final class ConversationVoice: NSObject, AVAudioPlayerDelegate {
    enum Phase { case idle, listening, transcribing, waiting, speaking }
    var phase = Phase.idle
    var live = false
    var level: Double = 0
    var elapsed: TimeInterval = 0
    var error: String?
    var permissionPending = false
    var transcribe: ((Data) async throws -> String?)?
    var synthesize: ((String) async throws -> Data)?
    var receive: ((String, Bool) throws -> Void)?
    var requestPermission: () async -> Bool = { await AVAudioApplication.requestRecordPermission() }
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meter: Task<Void, Never>?
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var heardSpeech = false
    private var lastSpeech: TimeInterval = 0
    private var currentURL: URL?
    private let draftKey: String
    init(draftKey: String = "conversation.pendingAudio") { self.draftKey = draftKey; super.init() }

    var isRecording: Bool { phase == .listening }
    var hasDraft: Bool {
        guard let path = UserDefaults.standard.string(forKey: draftKey) else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
    var status: String {
        switch phase {
        case .idle: return ""
        case .listening: return "Слушаю · \(Int(elapsed)) с"
        case .transcribing: return "Распознаю речь"
        case .waiting: return "Готовлю ответ"
        case .speaking: return "Говорю"
        }
    }

    func toggleDictation() {
        if isRecording { finishRecording(); return }
        guard phase == .idle, !permissionPending else { return }
        live = false
        begin()
    }

    func toggleLive() {
        if live { suspend(); return }
        guard phase == .idle, !permissionPending else { return }
        live = true
        begin()
    }

    private func begin() {
        guard !hasDraft else { pause("Сначала распознай или удали сохранённую запись."); return }
        let ticket = generation
        permissionPending = true
        error = nil
        operation = Task { [weak self] in
            guard let self else { return }
            let granted = await requestPermission()
            guard ticket == generation else { return }
            permissionPending = false
            guard granted else {
                pause("Разреши микрофон в настройках. Текст доступен.")
                return
            }
            do {
                let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("ConversationVoiceDrafts")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent(UUID().uuidString + ".m4a")
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try session.setActive(true)
                let capture = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
                capture.isMeteringEnabled = true
                guard capture.record() else { throw CocoaError(.fileWriteUnknown) }
                recorder = capture
                currentURL = url
                UserDefaults.standard.set(url.path, forKey: draftKey)
                phase = .listening
                elapsed = 0
                heardSpeech = false
                lastSpeech = 0
                meter = Task { [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(80))
                        guard !Task.isCancelled else { return }
                        self?.sample()
                    }
                }
            } catch { pause("Не удалось начать запись. Текст доступен.") }
        }
    }

    private func sample() {
        if let player, phase == .speaking {
            player.updateMeters()
            level = max(0, min(1, Double((player.averagePower(forChannel: 0) + 55) / 50)))
            return
        }
        guard let recorder, phase == .listening else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        let db = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, Double((db + 55) / 50)))
        if db > -36 { heardSpeech = true; lastSpeech = elapsed }
        if live && heardSpeech && elapsed > 0.5 && elapsed - lastSpeech > 1.15 { finishRecording() }
        else if live && !heardSpeech && elapsed > 20 { pause("Не услышал речь. Нажми голос, чтобы продолжить.") }
        else if elapsed >= 300 { finishRecording() }
    }

    private func finishRecording() {
        guard phase == .listening, let url = currentURL else { return }
        recorder?.stop(); recorder = nil; meter?.cancel(); meter = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        level = 0
        UserDefaults.standard.set(url.path, forKey: draftKey)
        currentURL = nil
        recognize(url)
    }

    func retryDraft() {
        guard phase == .idle, let path = UserDefaults.standard.string(forKey: draftKey) else { return }
        live = false
        recognize(URL(fileURLWithPath: path))
    }

    private func recognize(_ url: URL) {
        let ticket = generation
        phase = .transcribing
        error = nil
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                guard let transcribe else { throw URLError(.userAuthenticationRequired) }
                let text = try await transcribe(Data(contentsOf: url))?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard ticket == generation else { return }
                guard let text, !text.isEmpty else { pause("Не удалось услышать речь. Запись сохранена."); return }
                phase = live ? .waiting : .idle
                guard let receive else { throw URLError(.cannotParseResponse) }
                try receive(text, live)
                try? FileManager.default.removeItem(at: url)
                UserDefaults.standard.removeObject(forKey: draftKey)
            } catch {
                guard ticket == generation else { return }
                pause("Речь пока не распознана. Запись сохранена — можно повторить.")
            }
        }
    }

    func readReply(_ text: String) async {
        guard live else { return }
        let ticket = generation
        do {
            guard let synthesize else { throw URLError(.unsupportedURL) }
            let data = try await synthesize(String(text.prefix(4000)))
            guard live, ticket == generation else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let playback = try AVAudioPlayer(data: data)
            playback.delegate = self
            playback.isMeteringEnabled = true
            player = playback
            phase = .speaking
            guard playback.play() else { throw URLError(.cannotDecodeContentData) }
            meter?.cancel()
            meter = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(80))
                    guard !Task.isCancelled else { return }
                    self?.sample()
                }
            }
        } catch {
            guard ticket == generation else { return }
            pause("Ответ сохранён в чате. Озвучить пока не удалось.")
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, phase == .speaking else { return }
            self.player = nil
            meter?.cancel(); meter = nil; level = 0
            phase = .idle
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            if live && flag { begin() }
            else if !flag { pause("Воспроизведение прервано. Ответ есть в чате.") }
        }
    }

    func interruptPlayback() {
        guard phase == .speaking else { return }
        player?.stop(); player = nil; phase = .idle
        meter?.cancel(); meter = nil; level = 0
        if live { begin() }
    }

    func cancelDictation() {
        guard !live else { return }
        let path = UserDefaults.standard.string(forKey: draftKey)
        suspend()
        if let path {
            do {
                if FileManager.default.fileExists(atPath: path) { try FileManager.default.removeItem(atPath: path) }
                UserDefaults.standard.removeObject(forKey: draftKey)
                error = nil
            } catch { self.error = "Не удалось удалить запись." }
        }
    }

    func discardDraft() {
        guard phase == .idle, let path = UserDefaults.standard.string(forKey: draftKey) else { return }
        do {
            if FileManager.default.fileExists(atPath: path) { try FileManager.default.removeItem(atPath: path) }
            UserDefaults.standard.removeObject(forKey: draftKey); error = nil
        } catch { self.error = "Не удалось удалить запись." }
    }

    func pause(_ message: String) { suspend(); error = message }

    func suspend() {
        generation = UUID()
        operation?.cancel(); operation = nil
        meter?.cancel(); meter = nil
        recorder?.stop(); recorder = nil
        if let currentURL { UserDefaults.standard.set(currentURL.path, forKey: draftKey) }
        currentURL = nil
        player?.stop(); player = nil
        permissionPending = false
        live = false
        phase = .idle
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
