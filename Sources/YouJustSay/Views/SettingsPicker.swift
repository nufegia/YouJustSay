import SwiftUI

/// Keeps the system selection menu while using a quiet, neutral trigger.
struct SettingsPicker<Selection: Hashable>: View {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let label: (Selection) -> String
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    init(_ title: String, selection: Binding<Selection>, options: [Selection],
         label: @escaping (Selection) -> String) {
        self.title = title
        self._selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        NativeSettingsPicker(title: title, selection: $selection, options: options,
                             label: label, enabled: isEnabled)
        .frame(height: 28)
        .overlay {
            HStack(spacing: 12) {
                Text(label(selection))
                    .foregroundStyle(Color(nsColor: isEnabled ? .labelColor : .disabledControlTextColor))
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .font(.system(size: 13))
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(.background, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.primary.opacity(hovered && isEnabled ? 0.22 : 0.12)))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            // This label is outside the native menu's tracking/highlight state.
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onHover { hovered = $0 }
    }
}

private struct NativeSettingsPicker<Selection: Hashable>: NSViewRepresentable {
    let title: String
    @Binding var selection: Selection
    let options: [Selection]
    let label: (Selection) -> String
    let enabled: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        // SwiftUI draws the unchanged neutral field. AppKit owns menu tracking,
        // keyboard navigation, selection checkmarks, and accessibility semantics.
        button.isBordered = false
        button.isTransparent = true
        button.font = .systemFont(ofSize: 13)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectOption(_:))
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let titles = options.map(label)
        if button.itemTitles != titles {
            button.removeAllItems()
            // Add individual items so duplicate display labels keep their indices.
            for title in titles {
                button.menu?.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
            }
        }
        button.selectItem(at: options.firstIndex(of: selection) ?? -1)
        button.isEnabled = enabled
        button.setAccessibilityLabel(title)
        button.setAccessibilityValue(label(selection))
    }

    final class Coordinator: NSObject {
        var parent: NativeSettingsPicker
        init(_ parent: NativeSettingsPicker) { self.parent = parent }

        @objc func selectOption(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.enabled, parent.options.indices.contains(index) else { return }
            parent.selection = parent.options[index]
        }
    }
}
