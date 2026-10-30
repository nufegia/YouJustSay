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

extension FnMonitorTests {
    @MainActor func testTimeoutFailsOpenAndDoesNotRearmOnRefresh() {
        let monitor = FnMonitor()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)!
        event.flags = .maskSecondaryFn
        XCTAssertFalse(monitor.handle(.tapDisabledByTimeout, event: event))
        XCTAssertTrue(monitor.disabledAfterTimeout)
        monitor.refresh()
        XCTAssertFalse(monitor.running)
        var selections = 0
        monitor.onSelection = { selections += 1 }
        XCTAssertFalse(monitor.handle(.keyDown, event: event))
        XCTAssertEqual(selections, 0)
    }
    @MainActor func testNestedAuthorizationSuspensionPassesKeysThrough() {
        let monitor = FnMonitor()
        monitor.suspend()
        monitor.suspend()
        monitor.beginCapture()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)!
        event.flags = .maskSecondaryFn
        XCTAssertFalse(monitor.handle(.keyDown, event: event))
        monitor.resume()
        XCTAssertTrue(monitor.suspended)
        monitor.refresh()
        XCTAssertFalse(monitor.running)
        // Prevent this test from installing a real event tap when resuming.
        _ = monitor.handle(.tapDisabledByTimeout, event: event)
        monitor.resume()
        XCTAssertFalse(monitor.suspended)
        XCTAssertFalse(monitor.running)
    }
}

extension FnMonitorTests {
    @MainActor func testEventTapDefersWorkAndSuspensionDropsQueuedActions() async throws {
        let monitor = FnMonitor()
        var calls = 0
        monitor.onSelection = { calls += 1 }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)!
        event.flags = .maskSecondaryFn
        XCTAssertTrue(monitor.handleEventTap(.keyDown, event: event))
        XCTAssertEqual(calls, 0, "Event tap must return before app/UI work runs")
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(calls, 1)
        _ = monitor.handleEventTap(.keyUp, event: event)
        _ = monitor.handleEventTap(.keyDown, event: event)
        monitor.suspend()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(calls, 1, "Queued input must not start work during authorization")
    }
}

extension FnMonitorTests {
    @MainActor func testDisabledNotificationIsDeferredAndDeliveredOnce() async {
        let monitor = FnMonitor()
        var events: [String] = []
        monitor.onCancelPrimary = { events.append("cancel") }
        monitor.onMonitoringDisabled = { events.append("notice") }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        XCTAssertFalse(monitor.handleEventTap(.tapDisabledByTimeout, event: event))
        XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(monitor.handleEventTap(.tapDisabledByUserInput, event: event))
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(events, ["cancel", "notice"])
        XCTAssertTrue(monitor.disabledAfterTimeout)
        XCTAssertFalse(monitor.running)
    }
}
