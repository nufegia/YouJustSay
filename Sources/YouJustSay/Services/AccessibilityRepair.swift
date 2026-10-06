import Foundation

enum AccessibilityRepair {
    static let bundleIdentifier = "app.youjustsay.native"

    static func reset(bundleID: String?,
                      run: @Sendable ([String]) async throws -> Bool = runReset) async throws -> Bool {
        // Never fall back to resetting permissions for every app.
        guard bundleID == bundleIdentifier else { return false }
        return try await run(["reset", "Accessibility", bundleIdentifier])
    }

    private static func runReset(_ arguments: [String]) async throws -> Bool {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        }.value
    }
}
