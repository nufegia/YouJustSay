import XCTest
import AppKit
@testable import YouJustSay

final class SelectedTextTests: XCTestCase {
    @MainActor private func snapshot(location: Int = 0, value: String = "原文其余文字", pid: pid_t = 101) -> SelectedText.Snapshot {
        .init(target: .init(pid: pid, element: nil), text: "原文", range: CFRange(location: location, length: 2), fieldValue: value)
    }
    @MainActor private func insertion(board: NSPasteboard = .general, post: @escaping @MainActor (CGEvent) -> Void = { _ in },
                                     wait: @escaping @MainActor () async throws -> Void = {}) -> TextInsertion {
        TextInsertion(currentTarget: { .init(pid: 101, element: nil) }, isTrusted: { true }, postEvent: post, pasteboard: board, waitForPaste: wait)
    }
    @MainActor func testChangedFieldRangeOrContentsNeverPastes() async throws {
        let original = snapshot()
        for changed in [snapshot(location: 3), snapshot(value: "原文已改动"), snapshot(pid: 202)] {
            var posts = 0
            let service = SelectedText(read: { changed }, insertion: insertion(post: { _ in posts += 1 }))
            let warning = try await service.replace("整理结果", selection: original)
            XCTAssertEqual(warning, "selectionChanged"); XCTAssertEqual(posts, 0)
        }
    }
    @MainActor func testPasteConfirmsReplacementAndRestoresClipboard() async throws {
        let original = snapshot()
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("剪贴板原文", forType: .string)
        var posts = 0, consumed = false
        let insertion = insertion(board: board, post: { event in
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 9)
            XCTAssertEqual(event.flags, .maskCommand); posts += 1
        }, wait: {
            XCTAssertEqual(board.string(forType: .string), "整理结果"); consumed = true
        })
        let service = SelectedText(read: { original }, confirmed: { selection, text in
            XCTAssertTrue(consumed); XCTAssertEqual(selection.range.length, 2)
            XCTAssertEqual(text, "整理结果"); return true
        }, insertion: insertion, waitForVerification: {})
        let warning = try await service.replace("整理结果", selection: original)
        XCTAssertNil(warning); XCTAssertEqual(posts, 2)
        XCTAssertEqual(board.string(forType: .string), "剪贴板原文")
    }
    @MainActor func testSilentEditorFailureDoesNotReportSuccess() async throws {
        let original = snapshot()
        var posts = 0
        let service = SelectedText(read: { original }, confirmed: { _, _ in false },
                                   insertion: insertion(post: { _ in posts += 1 }), waitForVerification: {})
        let warning = try await service.replace("整理结果", selection: original)
        XCTAssertEqual(warning, "insertionFailed"); XCTAssertEqual(posts, 2)
    }
    @MainActor func testCopySettingCopiesWithoutTouchingSelectionOrRequiringFocus() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let original = snapshot()
        let service = SelectedText(read: { XCTFail("Copy must not inspect selection"); return nil },
                                   insertion: TextInsertion(isTrusted: { false }, postEvent: { _ in XCTFail("No keys for copy") }, pasteboard: board))
        let warning = try await service.replace("整理结果", selection: original, mode: .copy)
        XCTAssertNil(warning); XCTAssertEqual(board.string(forType: .string), "整理结果")
    }
    @MainActor func testTypingSettingUsesUnicodeEventsAndLeavesClipboardAlone() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("保留剪贴板", forType: .string)
        let original = snapshot()
        var posts = 0
        let service = SelectedText(read: { original }, confirmed: { _, _ in true }, insertion: insertion(board: board, post: { event in
            XCTAssertEqual(event.getIntegerValueField(.keyboardEventKeycode), 0); posts += 1
        }), waitForVerification: {})
        let warning = try await service.replace("整理结果", selection: original, mode: .typing)
        XCTAssertNil(warning); XCTAssertEqual(posts, 8)
        XCTAssertEqual(board.string(forType: .string), "保留剪贴板")
    }
    @MainActor func testUnchangedResultIsNoOp() async throws {
        let original = snapshot()
        let service = SelectedText(read: { original }, insertion: insertion(post: { _ in XCTFail("No-op should not paste") }))
        let warning = try await service.replace(original.text, selection: original)
        XCTAssertNil(warning)
    }
    @MainActor func testCancellationNeverReplacesSelection() async {
        let original = snapshot()
        let service = SelectedText(read: { original }, insertion: insertion(post: { _ in XCTFail("Cancelled paste") }))
        let task = Task { try await service.replace("整理结果", selection: original) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }
}
