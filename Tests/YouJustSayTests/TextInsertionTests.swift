import XCTest
import AppKit
import ApplicationServices
@testable import YouJustSay

final class TextInsertionTests: XCTestCase {
    @MainActor private final class Destination {
        var target = TextInsertion.Target(pid: 101, element: nil)
    }

    @MainActor private func clipboard() -> NSPasteboard {
        let board = NSPasteboard.withUniqueName()
        board.setString("原剪贴板", forType: .string)
        return board
    }

    @MainActor func testPasteUsesDestinationSelectedAtDeliveryAndRestoresClipboard() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let destination = Destination()
        var events = 0
        let insertion = TextInsertion(currentTarget: { destination.target }, isTrusted: { true },
                                      postEvent: { _ in events += 1 }, pasteboard: board, waitForPaste: {
            XCTAssertEqual(board.string(forType: .string), "你好")
        })
        destination.target = TextInsertion.Target(pid: 202, element: AXUIElementCreateApplication(202))
        let warning = try await insertion.insert("你好", mode: .paste)
        XCTAssertNil(warning)
        XCTAssertEqual(events, 2)
        XCTAssertEqual(board.string(forType: .string), "原剪贴板")
    }

    @MainActor func testTypingUsesLatestFieldAndLeavesClipboardUnchanged() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let initialCount = board.changeCount
        let destination = Destination()
        var events = 0
        let insertion = TextInsertion(currentTarget: { destination.target }, isTrusted: { true },
                                      postEvent: { _ in events += 1 }, pasteboard: board)
        destination.target = TextInsertion.Target(pid: 101, element: AXUIElementCreateApplication(202))
        let warning = try await insertion.insert("你好", mode: .typing)
        XCTAssertNil(warning)
        XCTAssertEqual(events, 4)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    @MainActor func testTypingStopsWhenFieldChangesWithoutCopying() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let initialCount = board.changeCount
        let destination = Destination()
        destination.target = TextInsertion.Target(pid: 101, element: AXUIElementCreateApplication(101))
        var events = 0
        let insertion = TextInsertion(currentTarget: { destination.target }, isTrusted: { true }, postEvent: { _ in
            events += 1
            if events == 2 { destination.target = TextInsertion.Target(pid: 101, element: AXUIElementCreateApplication(202)) }
        }, pasteboard: board)
        let warning = try await insertion.insert("你好", mode: .typing)
        XCTAssertEqual(warning, "targetChanged")
        XCTAssertEqual(events, 2)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    @MainActor func testPasteRestoresClipboardIfAppChangesBeforeShortcut() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        var calls = 0
        var events = 0
        let insertion = TextInsertion(currentTarget: {
            calls += 1
            return TextInsertion.Target(pid: calls == 1 ? 101 : 202, element: nil)
        }, isTrusted: { true }, postEvent: { _ in events += 1 }, pasteboard: board)
        let warning = try await insertion.insert("你好", mode: .paste)
        XCTAssertEqual(warning, "targetChanged")
        XCTAssertEqual(events, 0)
        XCTAssertEqual(board.string(forType: .string), "原剪贴板")
    }

    @MainActor func testOwnAppDoesNotInsertOrCopy() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let initialCount = board.changeCount
        var events = 0
        let insertion = TextInsertion(currentTarget: {
            TextInsertion.Target(pid: ProcessInfo.processInfo.processIdentifier, element: nil)
        }, isTrusted: { true }, postEvent: { _ in events += 1 }, pasteboard: board)
        let warning = try await insertion.insert("你好", mode: .paste)
        XCTAssertEqual(warning, "insertionFailed")
        XCTAssertEqual(events, 0)
        XCTAssertEqual(board.changeCount, initialCount)
    }

    @MainActor func testMissingPermissionDoesNotCopy() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let initialCount = board.changeCount
        let insertion = TextInsertion(isTrusted: { false }, pasteboard: board)
        let warning = try await insertion.insert("你好", mode: .typing)
        XCTAssertEqual(warning, "insertionFailed")
        XCTAssertEqual(board.changeCount, initialCount)
    }

    @MainActor func testCopyOnlyExplicitlyReplacesClipboardWithoutPermission() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let insertion = TextInsertion(isTrusted: { false }, pasteboard: board)
        let warning = try await insertion.insert("你好", mode: .copy)
        XCTAssertNil(warning)
        XCTAssertEqual(board.string(forType: .string), "你好")
    }

    @MainActor func testNewCopyDuringPasteIsPreservedEvenWithSameText() async throws {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let insertion = TextInsertion(currentTarget: { .init(pid: 101, element: nil) }, isTrusted: { true },
                                      postEvent: { _ in }, pasteboard: board, waitForPaste: {
            board.clearContents()
            board.setString("你好", forType: .string)
        })
        let warning = try await insertion.insert("你好", mode: .paste)
        XCTAssertNil(warning)
        XCTAssertEqual(board.string(forType: .string), "你好")
    }

    @MainActor func testCancellationWhileWaitingRestoresClipboard() async {
        let board = clipboard()
        defer { board.releaseGlobally() }
        let insertion = TextInsertion(currentTarget: { .init(pid: 101, element: nil) }, isTrusted: { true },
                                      postEvent: { _ in }, pasteboard: board, waitForPaste: { throw CancellationError() })
        do {
            _ = try await insertion.insert("你好", mode: .paste)
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(board.string(forType: .string), "原剪贴板")
    }
}
