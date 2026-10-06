import AppKit

/// Owns a temporary clipboard replacement without overwriting a later copy.
@MainActor final class TemporaryClipboard {
    private let pasteboard: NSPasteboard
    private let originalItems: [NSPasteboardItem]
    private let replacementChangeCount: Int

    init?(text: String, pasteboard: NSPasteboard) {
        let originalChangeCount = pasteboard.changeCount
        var items: [NSPasteboardItem] = []
        for source in pasteboard.pasteboardItems ?? [] {
            let item = NSPasteboardItem()
            for type in source.types {
                // Preserve every format, including images and file references.
                // If a promised format cannot be read, leave the clipboard alone.
                guard let data = source.data(forType: type) else { return nil }
                item.setData(data, forType: type)
            }
            items.append(item)
        }
        guard pasteboard.changeCount == originalChangeCount else { return nil }
        self.pasteboard = pasteboard
        originalItems = items
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            pasteboard.clearContents()
            if !items.isEmpty { pasteboard.writeObjects(items) }
            return nil
        }
        replacementChangeCount = pasteboard.changeCount
    }

    func restore() {
        guard pasteboard.changeCount == replacementChangeCount else { return }
        pasteboard.clearContents()
        if !originalItems.isEmpty { pasteboard.writeObjects(originalItems) }
    }
}
