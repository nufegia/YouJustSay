import SwiftUI

struct AboutView: View {
    let preferences: Preferences
    let updater: AppUpdater

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let release = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"
        return "\(release) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 22) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable().interpolation(.high)
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preferences.t("app")).font(.system(size: 26, weight: .semibold))
                        Text("YouJustSay").font(.title3).foregroundStyle(.secondary)
                        Text("\(preferences.t("version")) \(version)")
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                detail("privacy", text: "privacyShort")
                card("updates") {
                    VStack(alignment: .leading, spacing: 16) {
                        description("updatesShort")
                        HStack {
                            Button(preferences.t("checkForUpdates")) { updater.checkForUpdates() }
                                .disabled(!updater.canCheckForUpdates)
                            Spacer()
                            Toggle(preferences.t("automaticallyCheckForUpdates"), isOn: Binding(
                                get: { updater.automaticallyChecksForUpdates },
                                set: { updater.setAutomaticallyChecksForUpdates($0) }
                            )).toggleStyle(.switch)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30).padding(.bottom, 28)
        }
    }

    private func detail(_ title: String, text: String) -> some View {
        card(title) { description(text) }
    }

    private func description(_ key: String) -> some View {
        Text(preferences.t(key)).font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preferences.t(title)).font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
    }
}
