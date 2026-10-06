import XCTest
import AppKit
@testable import YouJustSay

final class TemporaryClipboardTests: XCTestCase {
    @MainActor func testRestoresMultipleItemsAndAllFormats() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("原文字", forType: .string)
        let imageBytes = Data([1, 2, 3, 4])
        first.setData(imageBytes, forType: .png)
        let second = NSPasteboardItem()
        second.setString("file:///tmp/example.txt", forType: .fileURL)
        board.writeObjects([first, second])
        let temporary = try XCTUnwrap(TemporaryClipboard(text: "识别文字", pasteboard: board))
        XCTAssertEqual(board.string(forType: .string), "识别文字")
        temporary.restore()
        let items = try XCTUnwrap(board.pasteboardItems)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].string(forType: .string), "原文字")
        XCTAssertEqual(items[0].data(forType: .png), imageBytes)
        XCTAssertEqual(items[1].string(forType: .fileURL), "file:///tmp/example.txt")
    }

    @MainActor func testRestoresEmptyClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents()
        let temporary = try XCTUnwrap(TemporaryClipboard(text: "识别文字", pasteboard: board))
        temporary.restore()
        XCTAssertTrue(board.pasteboardItems?.isEmpty ?? true)
    }

    @MainActor func testDoesNotOverwriteNewCopyAndRestoreIsIdempotent() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("原文字", forType: .string)
        let temporary = try XCTUnwrap(TemporaryClipboard(text: "识别文字", pasteboard: board))
        board.clearContents()
        board.setString("新复制", forType: .string)
        let count = board.changeCount
        temporary.restore()
        temporary.restore()
        XCTAssertEqual(board.string(forType: .string), "新复制")
        XCTAssertEqual(board.changeCount, count)
    }
}
