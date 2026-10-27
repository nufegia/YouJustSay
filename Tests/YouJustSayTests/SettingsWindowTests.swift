import AppKit
import XCTest
@testable import YouJustSay

final class SettingsWindowTests: XCTestCase {
    @MainActor func testOpeningSettingsRecoversHiddenAndOffscreenWindow() async throws {
        let app = NSApplication.shared
        let previousPolicy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { app.unhide(nil); window.close(); app.setActivationPolicy(previousPolicy) }
        window.setFrameOrigin(NSPoint(x: -100_000, y: -100_000))
        window.orderFrontRegardless()
        app.hide(nil)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(app.isHidden)
        AppDelegate.presentSettingsWindow(window)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(app.isHidden)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(NSScreen.screens.contains { $0.visibleFrame.contains(NSPoint(x: window.frame.midX, y: window.frame.maxY - 14)) })

        window.miniaturize(nil)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(window.isMiniaturized)
        AppDelegate.presentSettingsWindow(window)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(window.isMiniaturized)
        XCTAssertTrue(window.isVisible)

        window.close()
        AppDelegate.presentSettingsWindow(window)
        XCTAssertTrue(window.isVisible)
    }

    @MainActor func testAccessorySettingsStayVisibleWhenApplicationHides() async throws {
        let app = NSApplication.shared
        let previousPolicy = app.activationPolicy()
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        let baseline = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        baseline.isReleasedWhenClosed = false
        defer { app.unhide(nil); window.close(); baseline.close(); app.setActivationPolicy(previousPolicy) }
        AppDelegate.configureSettingsVisibility(window, showDock: false)
        window.orderFrontRegardless()
        baseline.orderFrontRegardless()
        app.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(200))
        app.hide(nil)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(app.isHidden, "Exercise an actual application hide")
        XCTAssertFalse(baseline.isVisible, "The unprotected settings window reproduces the disappearance")
        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.hidesOnDeactivate)

        // Re-enabling the Dock restores normal app hiding; hiding the Dock again
        // protects the same existing settings window, without recreating it.
        AppDelegate.configureSettingsVisibility(window, showDock: true)
        XCTAssertTrue(window.canHide)
        AppDelegate.configureSettingsVisibility(window, showDock: false)
        XCTAssertFalse(window.canHide)
        window.close()
        XCTAssertFalse(window.isVisible, "The user must still be able to close Settings")
    }
}
