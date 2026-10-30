import SwiftUI
import AppKit

/// A single-line secure editor with a fixed text area, independent of large control sizing.
struct CredentialField: View {
    let title: String
    @Binding var text: String
    @State private var focused = false
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        SingleLineCredentialEditor(title: title, text: $text, focused: $focused, enabled: isEnabled)
            .frame(height: 18)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(.background, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.primary.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor.opacity(focused ? 0.65 : 0), lineWidth: 3))
            .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct SingleLineCredentialEditor: NSViewRepresentable {
    let title: String
    @Binding var text: String
    @Binding var focused: Bool
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSecureTextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = enabled
        field.placeholderString = title
        field.setAccessibilityLabel(title)
        let clean = CredentialStore.normalized(text)
        if field.stringValue != clean { field.stringValue = clean }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SingleLineCredentialEditor
        init(_ parent: SingleLineCredentialEditor) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) { parent.focused = true }
        func controlTextDidEndEditing(_ notification: Notification) { parent.focused = false }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSecureTextField else { return }
            let clean = CredentialStore.normalized(field.stringValue)
            if clean != field.stringValue {
                if let editor = field.currentEditor() {
                    let old = editor.string as NSString
                    let cursor = min(editor.selectedRange.location, old.length)
                    let position = (CredentialStore.normalized(old.substring(to: cursor)) as NSString).length
                    editor.string = clean
                    editor.selectedRange = NSRange(location: min(position, (clean as NSString).length), length: 0)
                }
                field.stringValue = clean
            }
            parent.text = clean
        }
    }
}
