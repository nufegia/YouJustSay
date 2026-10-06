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
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
