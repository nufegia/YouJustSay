import SwiftUI

struct AboutView: View {
    let preferences: Preferences
    let updater: AppUpdater
    @State private var copied = false

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
                detail("updates", text: "updatesShort")
                HStack {
                    Button(preferences.t("checkForUpdates")) { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                    Spacer()
                    Toggle(preferences.t("automaticallyCheckForUpdates"), isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.setAutomaticallyChecksForUpdates($0) }
                    )).toggleStyle(.switch)
                }
                HStack(spacing: 12) {
                    Button(preferences.t("showApplication")) {
                        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                    }
                    Button(preferences.t(copied ? "appInfoCopied" : "copyAppInfo")) {
                        let info = "YouJustSay \(version)\nmacOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(info, forType: .string)
                        copied = true
                    }
                }
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30).padding(.bottom, 28)
        }
    }

    private func detail(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preferences.t(title)).font(.headline)
            Text(preferences.t(text)).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
    }
}
