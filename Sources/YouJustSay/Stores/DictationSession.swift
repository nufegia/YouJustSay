import Foundation
import AppKit
import Observation

@MainActor @Observable final class DictationSession {
    private static let minimumRecordingDuration: TimeInterval = 0.5
    enum Phase: String { case ready, requesting, recording, transcribing, polishing, inserting, paused }
    var phase: Phase = .ready
    var seconds = 0
    var level = 0.0
    var waveform = AudioWaveform()
    var error: String?
    var completed = false
    var copiedOnly = false
    var lastResult = ""
    var hasAudio = false
    var original = ""
    var recoverySeconds = 5
    var onPresentation: (() -> Void)?
    var onDismiss: (() -> Void)?
    private let recorder = AudioRecorder()
    private let client = ProviderClient()
    private let insertion = TextInsertion()
    private let selectedText = SelectedText()
    private var selection: SelectedText.Snapshot?
    private var task: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private var recovery = RecoveryWindow()
    private var generation = UUID()
    private var stopWhenReady = false
    var busy: Bool { phase != .ready && phase != .paused }

    func trigger(down: Bool, preferences: Preferences) {
        if preferences.holdToTalk {
            if down {
                if phase == .ready { toggle(preferences) }
            } else if phase == .requesting { stopWhenReady = true }
            else if phase == .recording { stop(preferences) }
        } else if down { toggle(preferences) }
    }
    func toggle(_ preferences: Preferences) {
        if phase == .recording { stop(preferences); return }
        if phase == .paused { resume(preferences); return }
        guard !busy else { return }
        onDismiss?()
        discard()
        completed = false; error = nil; stopWhenReady = false
        guard preferences.speechReady else { error = "missingSpeech"; onPresentation?(); return }
        phase = .requesting
        let token = generation
        task = Task {
            do {
                try await recorder.start()
                guard token == generation else { return }
                phase = .recording; seconds = 0
                if stopWhenReady { stop(preferences); return }
                onPresentation?()
                timer = Task {
                    while !Task.isCancelled {
                        seconds = Int(recorder.elapsed); level = recorder.level
                        waveform.append(level)
                        if seconds >= 300 { stop(preferences); return }
                        try? await Task.sleep(for: .milliseconds(80))
                    }
                }
            } catch {
                if token == generation {
                    handle(error); phase = .ready
                    if self.error != nil { onPresentation?() }
                }
            }
        }
    }
    private func stop(_ preferences: Preferences) {
        guard phase == .recording else { return }
        // Read the precise duration before stop() releases the recorder.
        guard recorder.elapsed >= Self.minimumRecordingDuration else {
            discard(); seconds = 0; onDismiss?()
            return
        }
        timer?.cancel(); recorder.stop(); level = 0; hasAudio = true; phase = .ready
        transcribe(preferences)
    }
    func transcribe(_ preferences: Preferences) {
        guard !busy else { return }
        guard preferences.speechReady else { error = "missingSpeech"; return }
        error = nil; phase = .transcribing
        let credentials = SpeechCredentials(key: preferences.doubaoKey, appID: preferences.appID, token: preferences.accessToken, legacy: preferences.legacyAuth)
        let language = preferences.recognitionLanguage
        let token = generation
        task = Task {
            do {
                let text = try await client.transcribe(audio: recorder.data(), credentials: credentials, language: language)
                try Task.checkCancellation()
                guard token == generation else { return }
                original = text
                phase = .ready
                if preferences.autoOrganize { polish(preferences) }
                else { deliver(text, preferences: preferences) }
            } catch { if token == generation { handle(error); phase = .ready } }
        }
    }
    func polish(_ preferences: Preferences) {
        guard !busy, !original.isEmpty else { return }
        guard !preferences.modelKey.isEmpty else { error = "missingLLM"; return }
        phase = .polishing; error = nil
        let source = original, style = preferences.style, configuration = preferences.textConfiguration
        let token = generation
        task = Task {
            do {
                let result = try await client.organize(text: source, style: style, configuration: configuration)
                try Task.checkCancellation()
                guard token == generation else { return }
                deliver(result, preferences: preferences)
            } catch { if token == generation { handle(error); phase = .ready } }
        }
    }
    func organizeSelection(_ preferences: Preferences) {
        guard !busy, phase != .paused else { return }
        discard(); onDismiss?()
        guard !preferences.modelKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "missingLLM"; onPresentation?(); return
        }
        guard let snapshot = selectedText.capture() else {
            error = "noSelectedText"; onPresentation?(); return
        }
        selection = snapshot; original = snapshot.text
        polish(preferences); onPresentation?()
    }
    func deliverOriginal(_ preferences: Preferences) { deliver(original, preferences: preferences, mode: .copy) }
    private func deliver(_ text: String, preferences: Preferences, mode: InsertionMode? = nil) {
        phase = .inserting
        let token = generation
        let output = preferences.chinesePreference.apply(to: text)
        let method = mode ?? preferences.insertion
        task = Task {
            do {
                let warning: String?
                if let selection, mode == nil {
                    warning = try await selectedText.replace(output, selection: selection, mode: method)
                } else { warning = try await insertion.insert(output, mode: method) }
                guard token == generation else { return }
                error = warning; completed = true; copiedOnly = method == .copy; lastResult = output; phase = .ready
                recorder.discard(); hasAudio = false; original = ""; selection = nil
                if warning == nil { scheduleCompletionDismissal() }
            } catch { if token == generation { handle(error); phase = .ready } }
        }
    }
    @discardableResult func escape() -> Bool {
        guard phase != .ready else { return false }
        if phase == .paused { discard(); onDismiss?(); return true }
        if phase == .transcribing || phase == .polishing {
            generation = UUID(); task?.cancel(); timer?.cancel()
            phase = .paused; recovery.begin(); recoverySeconds = 5
            recoveryTask?.cancel()
            recoveryTask = Task {
                while !Task.isCancelled && recovery.canResume() {
                    recoverySeconds = recovery.remaining()
                    try? await Task.sleep(for: .milliseconds(100))
                }
                guard !Task.isCancelled else { return }
                discard(); onDismiss?()
            }
        } else { discard(); onDismiss?() }
        return true
    }
    func resume(_ preferences: Preferences) {
        guard phase == .paused, recovery.canResume() else { return }
        recoveryTask?.cancel(); recovery.clear(); phase = .ready
        if !original.isEmpty && (selection != nil || preferences.autoOrganize) { polish(preferences) }
        else if !original.isEmpty { deliver(original, preferences: preferences) }
        else { transcribe(preferences) }
    }
    func copyLastResult(to pasteboard: NSPasteboard = .general) {
        guard !lastResult.isEmpty else { return }
        pasteboard.clearContents()
        guard pasteboard.setString(lastResult, forType: .string) else { return }
        if completed && phase == .ready {
            error = nil; copiedOnly = true
            scheduleCompletionDismissal()
        }
    }
    private func scheduleCompletionDismissal() {
        completionTask?.cancel()
        let token = generation
        completionTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard let self, token == generation, phase == .ready, completed, error == nil else { return }
            onDismiss?()
        }
    }
    func discard() {
        generation = UUID(); task?.cancel(); timer?.cancel(); recoveryTask?.cancel(); completionTask?.cancel()
        recorder.discard(); hasAudio = false; original = ""; selection = nil; level = 0; waveform = AudioWaveform()
        recovery.clear(); phase = .ready; error = nil; completed = false
    }
    private func handle(_ error: Error) {
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        if let failure = error as? AppFailure {
            switch failure {
            case .message(let key): self.error = key
            case .provider(let provider, let code): self.error = "\(provider): \(code)"
            }
        } else { self.error = error is DecodingError ? "response" : "network" }
    }
}
