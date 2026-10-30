import Foundation
import CoreServices
import OSLog
import Darwin

enum AccessibilityRepair {
    static let bundleIdentifier = "app.youjustsay.native"

    static func reset(bundleID: String?,
                      run: @Sendable ([String]) async throws -> Bool = runReset) async throws -> Bool {
        // Never fall back to resetting permissions for every app.
        guard bundleID == bundleIdentifier else { return false }
        return try await run(["reset", "Accessibility", bundleIdentifier])
    }

    static func registerCurrentApplication(_ url: URL) -> Bool {
        guard url.pathExtension == "app", Bundle(url: url)?.bundleIdentifier == bundleIdentifier else { return false }
        return LSRegisterURL(url as CFURL, true) == noErr
    }

    private static func runReset(_ arguments: [String]) async throws -> Bool {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            let errors = Pipe()
            process.standardError = errors
            try process.run()
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning && Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
            if process.isRunning {
                process.terminate()
                let grace = Date().addingTimeInterval(1)
                while process.isRunning && Date() < grace { try? await Task.sleep(for: .milliseconds(50)) }
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                Logger(subsystem: bundleIdentifier, category: "permissions").error("Accessibility reset timed out")
                return false
            }
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                let detail = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                Logger(subsystem: bundleIdentifier, category: "permissions").error("Accessibility reset failed: exit \(process.terminationStatus), \(detail, privacy: .private)")
            }
            return process.terminationStatus == 0
        }.value
    }
}
