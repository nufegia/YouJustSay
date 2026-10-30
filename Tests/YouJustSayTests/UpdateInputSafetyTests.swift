import XCTest
import CoreGraphics
@testable import YouJustSay

final class UpdateInputSafetyTests: XCTestCase {
    @MainActor func testDownloadExtractionAndInstallationShareOneSuspension() {
        let updater = AppUpdater()
        var transitions: [Bool] = []
        updater.onInstallationActivityChanged = { transitions.append($0) }
        updater.beginInstallationActivity(stage: "download")
        updater.beginInstallationActivity(stage: "extract-and-authorize")
        updater.beginInstallationActivity(stage: "install")
        XCTAssertEqual(transitions, [true])
        updater.finishInstallationActivity(error: NSError(domain: "NSOSStatusErrorDomain", code: -60008))
        updater.finishInstallationActivity(error: nil)
        XCTAssertEqual(transitions, [true, false])
        updater.beginInstallationActivity(stage: "extract-and-authorize")
        XCTAssertEqual(transitions, [true, false, true], "Cached retry must suspend again")
    }

    @MainActor func testUpgradeCannotRearmOrConsumeInputDuringActivation() async {
        let monitor = FnMonitor()
        let updater = AppUpdater()
        updater.onInstallationActivityChanged = { active in
            if active { monitor.suspend() } else { monitor.resume() }
        }
        // Keep tests from creating a real tap when the final suspension ends.
        monitor.suspend()
        var calls = 0
        monitor.onTrigger = { _ in calls += 1 }
        monitor.onSelection = { calls += 1 }
        updater.beginInstallationActivity(stage: "download")
        monitor.beginCapture()
        monitor.refresh() // app activation/settings onAppear during authorization
        XCTAssertFalse(monitor.running)
        XCTAssertNil(monitor.lastChecked, "Suspended refresh must not call permission APIs")
        for flags: CGEventFlags in [[], .maskSecondaryFn, [.maskCommand, .maskShift]] {
            for key in 0..<128 {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: true)!
                event.flags = flags
                for type: CGEventType in [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .rightMouseDown, .mouseMoved] {
                    XCTAssertFalse(monitor.handleEventTap(type, event: event))
                }
            }
        }
        XCTAssertEqual(calls, 0)
        updater.finishInstallationActivity(error: nil)
        XCTAssertTrue(monitor.suspended, "Update completion must preserve another suspension")
        XCTAssertFalse(monitor.running)
    }

    @MainActor func testTerminationSuspensionSurvivesUpdateCompletion() {
        let monitor = FnMonitor()
        let updater = AppUpdater()
        updater.onInstallationActivityChanged = { active in
            if active { monitor.suspend() } else { monitor.resume() }
        }
        updater.beginInstallationActivity(stage: "install")
        monitor.suspend() // applicationShouldTerminate, before credentials.flush()
        updater.finishInstallationActivity(error: nil)
        monitor.refresh()
        XCTAssertTrue(monitor.suspended)
        XCTAssertFalse(monitor.running)
    }
}
