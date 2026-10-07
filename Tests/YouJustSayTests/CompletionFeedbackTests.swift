import AppKit
import XCTest
@testable import YouJustSay

final class CompletionFeedbackTests: XCTestCase {
    @MainActor func testCopyAfterFocusChangedDismissesAfterOneSecond() async throws {
        let session = DictationSession()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally(); session.discard() }
        session.completed = true
        session.error = "targetChanged"
        session.lastResult = "整理结果"
        var dismissed = false
        session.onDismiss = { dismissed = true }

        session.copyLastResult(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "整理结果")
        XCTAssertNil(session.error)
        XCTAssertTrue(session.copiedOnly)
        XCTAssertFalse(dismissed)
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertFalse(dismissed, "Keep the success feedback visible briefly")
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertTrue(dismissed, "Dismiss at 1 second, rather than 1.5 seconds or never")
    }

    @MainActor func testOldCompletionCannotDismissANewSession() async throws {
        let session = DictationSession()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally(); session.discard() }
        session.completed = true
        session.lastResult = "previous result"
        var dismissals = 0
        session.onDismiss = { dismissals += 1 }
        session.copyLastResult(to: pasteboard)
        await Task.yield()
        session.discard()
        session.phase = .polishing
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(dismissals, 0)
    }

    @MainActor func testCopyLastFromMenuDuringWorkDoesNotDismissOrClearError() async throws {
        let session = DictationSession()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally(); session.discard() }
        session.lastResult = "previous result"
        session.phase = .polishing
        session.error = "network"
        var dismissals = 0
        session.onDismiss = { dismissals += 1 }
        session.copyLastResult(to: pasteboard)
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(pasteboard.string(forType: .string), "previous result")
        XCTAssertEqual(session.error, "network")
        XCTAssertEqual(dismissals, 0)
    }
}
