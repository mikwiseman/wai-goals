import AVFoundation
import Foundation
import Observation

@MainActor @Observable
final class JournalRecorder: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var permissionPending = false
    var hasRecording: Bool
    var error: String?
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var requestID = UUID()
    private let url: URL

    init(draftID: String) {
        let folder = URL.applicationSupportDirectory.appendingPathComponent("VoiceDrafts", isDirectory: true)
        url = folder.appendingPathComponent(draftID + ".m4a")
        hasRecording = FileManager.default.fileExists(atPath: url.path)
        super.init()
    }
    func start() async {
        guard !isRecording, !permissionPending, !hasRecording else { return }
        permissionPending = true; error = nil
        requestID = UUID(); let id = requestID
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard id == requestID else { return }
        defer { permissionPending = false }
        guard allowed else { error = "Разреши доступ к микрофону в настройках iPhone. Можно также написать текст."; return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try session.setActive(true)
            let recording = try AVAudioRecorder(url: url, settings: [AVFormatIDKey:Int(kAudioFormatMPEG4AAC), AVSampleRateKey:16000, AVNumberOfChannelsKey:1, AVEncoderAudioQualityKey:AVAudioQuality.medium.rawValue])
            recording.delegate = self
            guard recording.record(forDuration:300) else { throw CocoaError(.fileWriteUnknown) }
            recorder = recording
            isRecording = true
        } catch {
            try? AVAudioSession.sharedInstance().setActive(false, options:.notifyOthersOnDeactivation)
            self.error = "Не удалось начать запись. Попробуй ещё раз или напиши текст."
        }
    }
    func stop() {
        guard isRecording else { return }
        recorder?.stop()
        finish()
    }
    private func finish() {
        guard isRecording else { return }
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options:.notifyOthersOnDeactivation)
        hasRecording = FileManager.default.fileExists(atPath:url.path)
    }
    func pause() { requestID = UUID(); permissionPending = false; stop() }
    func audio() throws -> Data { try Data(contentsOf:url) }
    func clear() {
        do {
            if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
            hasRecording = false
        } catch { self.error = "Не удалось удалить аудиозапись." }
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finish() }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in self?.finish(); self?.error = "Запись прервалась. Доступный фрагмент сохранён." }
    }
}
