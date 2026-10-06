import SwiftUI

/// Shared visual container for every dictation state. Content determines its size.
struct FloatingBarSurface<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(minHeight: 36)
            .background {
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}

struct FloatingBarButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        FloatingBarButtonLabel(configuration: configuration, prominent: prominent, reduceMotion: reduceMotion)
    }

    private struct FloatingBarButtonLabel: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        let reduceMotion: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(prominent ? .primary : .secondary)
                .padding(.horizontal, prominent ? 10 : 0)
                .frame(minWidth: 28, minHeight: 28)
                .background(.primary.opacity(configuration.isPressed ? 0.14 : hovered ? 0.10 : prominent ? 0.06 : 0), in: Capsule())
                .contentShape(Capsule())
                .onHover { hovered = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        }
    }
}
