import XCTest
import CoreGraphics
@testable import YouJustSay

final class FnMonitorTests: XCTestCase {
    @MainActor @discardableResult private func send(_ monitor: FnMonitor, _ type: CGEventType, key: Int64 = 63, flags: CGEventFlags = []) -> Bool {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: type != .keyUp)!
        event.flags = flags; event.setIntegerValueField(.keyboardEventKeycode, value: key)
        return monitor.handle(type, event: event)
    }
    @MainActor func testFnSpaceDoesNotToggleRecordingAndConsumesRepeatAndRelease() {
        let monitor = FnMonitor()
        var recording: [Bool] = [], selections = 0
        monitor.onTrigger = { recording.append($0) }; monitor.onSelection = { selections += 1 }
        send(monitor, .flagsChanged, flags: .maskSecondaryFn)
        XCTAssertTrue(send(monitor, .keyDown, key: 49, flags: .maskSecondaryFn))
        XCTAssertTrue(send(monitor, .keyDown, key: 49, flags: .maskSecondaryFn))
        send(monitor, .flagsChanged)
        XCTAssertTrue(send(monitor, .keyUp, key: 49))
        XCTAssertEqual(selections, 1); XCTAssertEqual(recording, [])
        send(monitor, .flagsChanged, flags: .maskSecondaryFn); send(monitor, .flagsChanged)
        XCTAssertEqual(recording, [true, false])
    }
    @MainActor func testHoldChordCancelsGestureWithoutSubmittingRecording() async throws {
        let monitor = FnMonitor(); monitor.holdToTalk = true
        var recording: [Bool] = [], cancelled = 0, selections = 0
        monitor.onTrigger = { recording.append($0) }
        monitor.onCancelPrimary = { cancelled += 1 }; monitor.onSelection = { selections += 1 }
        send(monitor, .flagsChanged, flags: .maskSecondaryFn)
        try await Task.sleep(for: .milliseconds(300))
        send(monitor, .keyDown, key: 49, flags: .maskSecondaryFn)
        send(monitor, .keyUp, key: 49, flags: .maskSecondaryFn); send(monitor, .flagsChanged)
        XCTAssertEqual(recording, [true]); XCTAssertEqual(cancelled, 1); XCTAssertEqual(selections, 1)
    }
    @MainActor func testCustomShortcutAndDuplicateCapture() {
        let monitor = FnMonitor()
        var captured: Shortcut?
        monitor.onSelectionCaptured = { captured = $0 }
        monitor.beginCapture(selection: true)
        send(monitor, .flagsChanged, flags: .maskSecondaryFn); send(monitor, .flagsChanged)
        XCTAssertNil(captured); XCTAssertEqual(monitor.captureError, "shortcutConflict")
        send(monitor, .keyDown, key: 8, flags: [.maskCommand, .maskShift])
        XCTAssertEqual(captured?.keyCode, 8); XCTAssertFalse(monitor.capturing)
        var count = 0; monitor.onSelection = { count += 1 }
        send(monitor, .keyDown, key: 8, flags: [.maskCommand, .maskShift])
        XCTAssertEqual(count, 1)
    }
}
