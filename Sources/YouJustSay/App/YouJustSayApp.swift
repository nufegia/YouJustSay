import AppKit

@main struct YouJustSayApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--verify-providers"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            Task { let success = await LiveVerification.run(audioPath: path); exit(success ? 0 : 1) }
            app.run()
            return
        }
        #endif
        // Installed and development copies must not both intercept global input.
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            existing.activate()
            return
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
