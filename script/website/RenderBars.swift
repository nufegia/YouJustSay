import AppKit
import SwiftUI

// Read-only fixtures for the production DictationBar view. No microphone,
// keychain, network, preferences writes, or installed-app interaction.
@MainActor final class Preferences {
    func t(_ key: String) -> String { Language.simplified.text(key) }
}
@MainActor final class DictationSession {
    enum Phase: String { case ready, recording, transcribing, polishing, paused }
    var phase: Phase = .ready
    var error: String?
    var waveform = AudioWaveform()
    var recoverySeconds = 5
    var completed = false
    var copiedOnly = false
    var lastResult = ""
    var original = ""
    var hasAudio = false
    func toggle(_ preferences: Preferences) {}
    func resume(_ preferences: Preferences) {}
    func copyLastResult() {}
    func polish(_ preferences: Preferences) {}
    func deliverOriginal(_ preferences: Preferences) {}
    func transcribe(_ preferences: Preferences) {}
    func escape() -> Bool { false }
    func discard() {}
}
@main struct RenderBars {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for dark in [false, true] {
            for state in ["recording", "transcribing", "polishing", "completed", "paused"] {
                let session = DictationSession()
                session.phase = DictationSession.Phase(rawValue: state) ?? .ready
                session.completed = state == "completed"
                for level in [0.10,0.3,0.6,0.85,0.45,0.95,0.72,0.25,0.12,0.5,0.9,0.65,0.35,0.15,0.45,0.8,0.55,0.2,0.1] { session.waveform.append(level) }
                let view = DictationBar(preferences: Preferences(), session: session, openSettings: {}, dismiss: {}, resize: {_ in})
                    .environment(\.colorScheme, dark ? .dark : .light)
                let hosting = NSHostingView(rootView: view)
                hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                let size = hosting.fittingSize
                hosting.frame = NSRect(origin: .zero, size: size)
                hosting.layoutSubtreeIfNeeded()
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 3), pixelsHigh: Int(size.height * 3), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("Cannot create bitmap") }
                bitmap.size = size
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode") }
                let name = "\(state)-\(dark ? "dark" : "light").png"
                try data.write(to: output.appendingPathComponent(name))
                print("\(name) \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
            }
        }
    }
}
