import Foundation
import Observation
import Sparkle

@MainActor @Observable final class AppUpdater {
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var observation: NSKeyValueObservation?
    private(set) var canCheckForUpdates = false
    private(set) var automaticallyChecksForUpdates = false

    func start() {
        // A plain SwiftPM executable has no app Info.plist or embedded updater helpers.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        controller.startUpdater()
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor [weak self] in self?.canCheckForUpdates = enabled }
        }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }
}
