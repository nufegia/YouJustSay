import AVFoundation
import Foundation

@MainActor final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var url: URL?
    var elapsed: TimeInterval { recorder?.currentTime ?? 0 }
    var level: Double {
        recorder?.updateMeters()
        return AudioWaveform.normalized(decibels: Double(recorder?.averagePower(forChannel: 0) ?? -60))
    }
    func start() async throws {
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        try Task.checkCancellation()
        guard allowed else { throw AppFailure.message("micDenied") }
        discard()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("youjustsay-\(UUID().uuidString).wav")
        url = file
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let audio = try AVAudioRecorder(url: file, settings: settings)
        audio.isMeteringEnabled = true
        guard audio.prepareToRecord(), audio.record() else { throw AppFailure.message("micFailed") }
        recorder = audio
    }
    func stop() { recorder?.stop(); recorder = nil }
    func data() throws -> Data {
        guard let url else { throw AppFailure.message("empty") }
        let data = try Data(contentsOf: url)
        guard data.count > 1000 else { throw AppFailure.message("empty") }
        return data
    }
    func discard() {
        stop()
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }
}
