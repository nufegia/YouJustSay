import Foundation
import Observation
import Sparkle
import OSLog

@MainActor @Observable final class AppUpdater: NSObject, SPUUpdaterDelegate {
    @ObservationIgnored private lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    private let logger = Logger(subsystem: "app.youjustsay.native", category: "update")
    var onInstallationActivityChanged: ((Bool) -> Void)?
    private(set) var installationActive = false

    func beginInstallationActivity(stage: String) {
        logger.notice("Update stage: \(stage, privacy: .public)")
        guard !installationActive else { return }
        installationActive = true
        // Synchronous: release the event tap before Sparkle can enter authorization.
        onInstallationActivityChanged?(true)
    }

    func finishInstallationActivity(error: Error?) {
        if let error {
            let error = error as NSError
            logger.error("Update finished with error domain=\(error.domain, privacy: .public) code=\(error.code)")
        } else { logger.notice("Update cycle finished") }
        guard installationActive else { return }
        installationActive = false
        onInstallationActivityChanged?(false)
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        beginInstallationActivity(stage: "download")
    }
    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        // Also covers cached downloads and automatic updates. Sparkle invokes this
        // before launching its installer and asking authd for authorization.
        beginInstallationActivity(stage: "extract-and-authorize")
    }
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        beginInstallationActivity(stage: "install")
    }
    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        beginInstallationActivity(stage: "relaunch")
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        finishInstallationActivity(error: error)
    }
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
