import AppKit
import ApplicationServices

/// Holds the destination and selection for the duration of the provider request.
@MainActor final class SelectedText {
    struct Snapshot {
        let target: TextInsertion.Target
        let text: String
        let range: CFRange
        let fieldValue: String?
        func matches(_ other: Snapshot?) -> Bool {
            guard let other else { return false }
            return target.matches(other.target) && text == other.text && range.location == other.range.location
                && range.length == other.range.length && fieldValue == other.fieldValue
        }
    }
    private let read: @MainActor () -> Snapshot?
    private let confirmed: @MainActor (Snapshot, String) -> Bool
    private let insertion: TextInsertion
    private let waitForVerification: @MainActor () async throws -> Void
    init(read: @escaping @MainActor () -> Snapshot? = SelectedText.focusedSelection,
         confirmed: @escaping @MainActor (Snapshot, String) -> Bool = SelectedText.replacementConfirmed,
         insertion: TextInsertion = TextInsertion(),
         waitForVerification: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .milliseconds(100)) }) {
        self.read = read; self.confirmed = confirmed; self.insertion = insertion
        self.waitForVerification = waitForVerification
    }
    func capture() -> Snapshot? { read() }
    func replace(_ text: String, selection: Snapshot, mode: InsertionMode = .paste) async throws -> String? {
        try Task.checkCancellation()
        // Copy-only follows the same setting and never modifies the selected text.
        if mode == .copy { return try await insertion.insert(text, mode: mode) }
        guard selection.matches(read()) else { return "selectionChanged" }
        if text == selection.text { return nil }
        // Use exactly the same paste/typing path as voice input. AXSelectedText
        // writes can report success in web editors without updating their DOM.
        if let warning = try await insertion.insert(text, mode: mode, expectedTarget: selection.target) { return warning }
        try await waitForVerification()
        try Task.checkCancellation()
        return confirmed(selection, text) ? nil : "insertionFailed"
    }
    private static func focusedSelection() -> Snapshot? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var selected: CFTypeRef?, rangeValue: CFTypeRef?, value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.length > 0 else { return nil }
        _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        return Snapshot(target: .init(pid: app.processIdentifier, element: element), text: text, range: range, fieldValue: value as? String)
    }
    private static func replacementConfirmed(_ selection: Snapshot, _ text: String) -> Bool {
        guard selection.target.matches(TextInsertion.focusedTarget()), let element = selection.target.element else { return false }
        var value: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        if let before = selection.fieldValue, let after = value as? String {
            let range = NSRange(location: selection.range.location, length: selection.range.length)
            let source = before as NSString
            guard range.location >= 0, range.length >= 0, range.location <= source.length,
                  range.length <= source.length - range.location else { return false }
            return after == source.replacingCharacters(in: range, with: text)
        }
        // Some contenteditable fields expose only their selection, not AXValue.
        // Confirm the caret moved to the end of the replacement in the same field.
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return false }
        var range = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else { return false }
        return range.length == 0 && range.location == selection.range.location + text.utf16.count
    }
}
