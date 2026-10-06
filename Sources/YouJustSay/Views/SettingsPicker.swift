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
        Menu {
            ForEach(options, id: \.self) { option in
                Toggle(label(option), isOn: Binding(
                    get: { selection == option },
                    set: { if $0 { selection = option } }
                ))
                .toggleStyle(.checkbox)
            }
        } label: {
            HStack(spacing: 12) {
                Text(label(selection)).lineLimit(1).truncationMode(.tail)
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
            .accessibilityElement(children: .combine)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(SettingsMenuButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}

private struct SettingsMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
