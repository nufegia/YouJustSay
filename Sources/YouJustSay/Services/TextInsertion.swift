import AppKit
import ApplicationServices

@MainActor final class TextInsertion {
    struct Target {
        let pid: pid_t
        let element: AXUIElement?

        func matches(_ current: Target?) -> Bool {
            guard let current, current.pid == pid else { return false }
            guard let element else { return true }
            guard let currentElement = current.element else { return false }
            return CFEqual(element, currentElement)
        }
    }
    private let currentTarget: @MainActor () -> Target?
    private let isTrusted: @MainActor () -> Bool
    private let postEvent: @MainActor (CGEvent) -> Void
    private let pasteboard: NSPasteboard
    private let waitForPaste: @MainActor () async throws -> Void

    init(currentTarget: @escaping @MainActor () -> Target? = TextInsertion.focusedTarget,
         isTrusted: @escaping @MainActor () -> Bool = { AXIsProcessTrusted() },
         postEvent: @escaping @MainActor (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) },
         pasteboard: NSPasteboard = .general,
         waitForPaste: @escaping @MainActor () async throws -> Void = {
             try await Task.sleep(for: .milliseconds(750))
         }) {
        self.currentTarget = currentTarget
        self.isTrusted = isTrusted
        self.postEvent = postEvent
        self.pasteboard = pasteboard
        self.waitForPaste = waitForPaste
    }

    private static func focusedTarget() -> Target? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        var value: CFTypeRef?
        let application = AXUIElementCreateApplication(pid)
        let result = AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString, &value)
        let element: AXUIElement?
        if result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            element = (value as! AXUIElement)
        } else { element = nil }
        return Target(pid: pid, element: element)
    }
    func insert(_ text: String, mode: InsertionMode) async throws -> String? {
        try Task.checkCancellation()
        if mode == .copy { copyText(text); return nil }
        guard isTrusted() else { return "insertionFailed" }
        // Resolve the destination only when the text is ready. Recording and
        // recognition may happen while the user moves to another input field.
        guard let target = currentTarget(), target.pid != ProcessInfo.processInfo.processIdentifier else {
            return "insertionFailed"
        }
        let source = CGEventSource(stateID: .privateState)
        if mode == .paste {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return "insertionFailed" }
            guard let clipboard = TemporaryClipboard(text: text, pasteboard: pasteboard) else { return "insertionFailed" }
            defer { clipboard.restore() }
            guard target.matches(currentTarget()) else { return "targetChanged" }
            down.flags = .maskCommand; up.flags = .maskCommand
            postEvent(down); postEvent(up)
            // Posting the shortcut is asynchronous; allow the receiving app to
            // consume the clipboard before restoring it. Cancellation restores too.
            try await waitForPaste()
        } else {
            // Unicode events avoid dependence on the active keyboard layout.
            for character in text {
                try Task.checkCancellation()
                guard target.matches(currentTarget()) else {
                    return "targetChanged"
                }
                let units = Array(String(character).utf16)
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return "insertionFailed" }
                units.withUnsafeBufferPointer { buffer in
                    down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
                    up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
                }
                postEvent(down); postEvent(up)
                try await Task.sleep(for: .milliseconds(2))
            }
        }
        return nil
    }
    private func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
