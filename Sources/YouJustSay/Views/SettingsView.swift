import SwiftUI
import AVFoundation
struct SettingsView: View {
    @Bindable var preferences: Preferences
    @Bindable var login: LoginItem
    @Bindable var monitor: FnMonitor
    let applyVisibility: () -> Void
    @State private var speechTest = APIConnectionTest()
    @State private var textTest = APIConnectionTest()
    private var pageTitle: String {
        switch preferences.settingsTab {
        case .general: "general"
        case .interaction: "interaction"
        case .models: "modelConfiguration"
        case .permissions: "permissions"
        case .about: "about"
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable().frame(width: 36, height: 36)
                        .accessibilityHidden(true)
                    Text(preferences.t("app")).font(.system(size: 15, weight: .semibold))
                }.padding(.horizontal, 12)
                VStack(spacing: 5) {
                    tab(.general, title: "general", icon: "slider.horizontal.3")
                    tab(.interaction, title: "interaction", icon: "keyboard")
                    tab(.models, title: "modelConfiguration", icon: "waveform")
                    tab(.permissions, title: "permissions", icon: "lock.shield")
                    tab(.about, title: "about", icon: "info.circle")
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 14)
            .frame(width: 220)
            .background(.regularMaterial)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(preferences.t(pageTitle)).font(.system(size: 25, weight: .semibold))
                }
                .padding(.horizontal, 30).padding(.top, 28).padding(.bottom, 24)
                Group {
                    switch preferences.settingsTab {
                    case .general: general
                    case .interaction: interaction
                    case .models: models
                    case .permissions: permissions
                    case .about: AboutView(preferences: preferences)
                    }
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 816)
        .frame(maxHeight: .infinity)
        .environment(\.locale, Locale(identifier: preferences.language == .automatic ? Language.initial.rawValue : preferences.language.rawValue))
        .onChange(of: preferences.showDock) { applyVisibility() }
        .onChange(of: preferences.showMenu) { applyVisibility() }
        .onChange(of: preferences.language) { applyVisibility() }
    }
    private func tab(_ selection: SettingsTab, title: String, icon: String) -> some View {
        let selected = preferences.settingsTab == selection
        return Button {
            preferences.settingsTab = selection
        } label: {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(preferences.t(title)).font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12).frame(height: 38)
            .background(selected ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preferences.t(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func settingsForm<Content: View>(disabled: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content() }
                .disabled(disabled)
                .toggleStyle(.switch)
                .pickerStyle(.menu)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30).padding(.bottom, 28)
        }
    }
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != pageTitle && title != "insertion" {
                Text(preferences.t(title)).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary).padding(.leading, 2)
            }
            VStack(alignment: .leading, spacing: 18) { content() }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.07)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title).font(.system(size: 13)).frame(width: 160, alignment: .leading)
            Spacer(minLength: 0)
            HStack(spacing: 10) { content() }
                .frame(width: 304, alignment: .trailing)
        }.frame(minHeight: 24)
    }
    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(preferences.t(title)).font(.system(size: 13))
            Spacer()
            Toggle(preferences.t(title), isOn: isOn).labelsHidden().controlSize(.small)
        }.frame(minHeight: 24)
    }
    private var general: some View {
        settingsForm {
            settingsSection("startupAppearance") {
                settingsRow(preferences.t("language")) {
                    SettingsPicker(preferences.t("language"), selection: $preferences.language, options: Language.allCases) { $0 == .automatic ? preferences.t("automatic") : $0.name }
                }
                settingsToggle("login", isOn: Binding(get: { login.enabled || login.needsApproval }, set: { login.setEnabled($0) }))
                if login.needsApproval { Button(preferences.t("loginApproval")) { login.openSystemSettings() } }
                if let error = login.error { Text(preferences.t(error)).foregroundStyle(.red).font(.caption) }
            }
            settingsSection("visibility") {
                settingsToggle("showDock", isOn: $preferences.showDock)
                settingsToggle("showMenu", isOn: $preferences.showMenu)
            }
            Text(preferences.t("settingsAccessHint")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var interaction: some View {
        settingsForm {
            settingsSection("interaction") {
                settingsRow(preferences.t("shortcut")) {
                    Text(preferences.shortcut.display).font(.system(.body, design: .monospaced).weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    Button(preferences.t("changeShortcut")) { monitor.beginCapture() }.disabled(!monitor.running)
                }
                if monitor.capturing { Text(preferences.t("captureShortcut")).font(.caption).foregroundStyle(.orange) }
                settingsRow(preferences.t("interaction")) {
                    SettingsPicker(preferences.t("interaction"), selection: $preferences.holdToTalk, options: [false, true]) { preferences.t($0 ? "holdFn" : "toggleFn").replacingOccurrences(of: "Fn", with: preferences.shortcut.display) }
                }
            }
            settingsSection("insertion") {
                settingsRow(preferences.t("insertion")) {
                    SettingsPicker(preferences.t("insertion"), selection: $preferences.insertion, options: InsertionMode.allCases) { preferences.t($0 == .copy ? "copyOnly" : $0.rawValue) }
                }
                Text(preferences.t(preferences.insertion.rawValue + "InsertionHint"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var models: some View {
        VStack(spacing: 0) {
            settingsForm(disabled: preferences.loadingCredentials) {
                settingsSection("speech") {
                    settingsRow(preferences.t("provider")) { Text(preferences.t("doubao")).foregroundStyle(.secondary) }
                    settingsRow(preferences.t("auth")) {
                        SettingsPicker(preferences.t("auth"), selection: $preferences.legacyAuth, options: [false, true]) { preferences.t($0 ? "legacy" : "modern") }
                    }
                    Group {
                        if preferences.legacyAuth {
                            settingsRow("App ID") { TextField("App ID", text: $preferences.appID) }
                            settingsRow("Access Token") {
                                SecureField("Access Token", text: $preferences.accessToken)
                                speechTestButton
                            }
                        } else {
                            settingsRow(preferences.t("speechKey")) {
                                SecureField(preferences.t("speechKey"), text: $preferences.doubaoKey)
                                speechTestButton
                            }
                        }
                    }
                    testResult(speechTest)
                    settingsRow(preferences.t("recognitionLanguage")) {
                        SettingsPicker(preferences.t("recognitionLanguage"), selection: $preferences.recognitionLanguage, options: RecognitionLanguage.allCases) { $0.name(in: preferences.language) }
                    }
                    settingsRow(preferences.t("chinesePreference")) {
                        SettingsPicker(preferences.t("chinesePreference"), selection: $preferences.chinesePreference, options: ChinesePreference.allCases) { preferences.t($0.rawValue) }
                    }
                }
                settingsSection("organizer") {
                    settingsToggle("polishSwitch", isOn: $preferences.autoOrganize)
                    settingsRow(preferences.t("provider")) {
                        SettingsPicker(preferences.t("provider"), selection: $preferences.provider, options: TextProvider.allCases) { preferences.t($0.rawValue) }
                    }
                    settingsRow(preferences.t(preferences.provider == .ark ? "arkKey" : "apiKey")) {
                        SecureField(preferences.t(preferences.provider == .ark ? "arkKey" : "apiKey"), text: $preferences.modelKey)
                        Button(preferences.t(textTest.running ? "testingAPI" : "testAPI")) {
                            let configuration = preferences.textConfiguration
                            textTest.start { try await ProviderClient().testText(configuration: configuration) }
                        }.disabled(textTest.running || preferences.modelKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    testResult(textTest)
                    if preferences.provider == .ark {
                        settingsRow(preferences.t("model")) {
                            Text(TextProvider.ark.defaultModel).font(.caption).textSelection(.enabled)
                        }
                    } else {
                        settingsRow(preferences.t("model")) { TextField(preferences.t("model"), text: $preferences.model) }
                        settingsRow(preferences.t("baseURL")) { TextField(preferences.t("baseURL"), text: $preferences.customURL) }
                    }
                    settingsRow(preferences.t("style")) {
                        SettingsPicker(preferences.t("style"), selection: $preferences.style, options: WritingStyle.allCases) { preferences.t($0.rawValue) }
                    }
                    Text(preferences.t(preferences.style.rawValue + "ShortHint"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = preferences.credentialError {
                HStack {
                    Text(preferences.t(error)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(preferences.t("resyncCredentials")) {
                        Task { await preferences.credentials.authorizeIfNeeded() }
                    }.disabled(preferences.credentials.loading)
                }.padding(.horizontal, 30).padding(.top, 16).padding(.bottom, 24)
            }
        }
        .task { await preferences.credentials.authorizeIfNeeded() }
        .onChange(of: [preferences.doubaoKey, preferences.appID, preferences.accessToken, String(preferences.legacyAuth)]) { speechTest.reset() }
        .onChange(of: [preferences.modelKey, preferences.provider.rawValue, preferences.model, preferences.customURL]) { textTest.reset() }
        .onDisappear { speechTest.reset(); textTest.reset() }
    }
    private var speechTestButton: some View {
        Button(preferences.t(speechTest.running ? "testingAPI" : "testAPI")) {
            let credentials = SpeechCredentials(key: preferences.doubaoKey, appID: preferences.appID, token: preferences.accessToken, legacy: preferences.legacyAuth)
            speechTest.start { try await ProviderClient().testSpeech(credentials: credentials) }
        }.disabled(speechTest.running || !preferences.speechReady)
    }
    @ViewBuilder private func testResult(_ test: APIConnectionTest) -> some View {
        if let result = test.result {
            switch result {
            case .success:
                Label(preferences.t("testAPISuccess"), systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            case .failure(let key):
                Text(preferences.t("testAPIFailed") + " " + preferences.t(key))
                    .font(.caption).foregroundStyle(.red)
            case .providerFailure(let provider, let code):
                Text(preferences.t("testAPIFailed") + " \(provider): \(code)")
                    .font(.caption).foregroundStyle(.red)
            }
        }
    }
    private var permissions: some View {
        settingsForm {
            settingsSection("permissions") {
                permissionRow("accessibility", status: monitor.accessibility ? "granted" : "notGranted", granted: monitor.accessibility) {
                    if monitor.accessibility { monitor.manageAccessibility() } else { monitor.requestAccessibility() }
                }
                permissionRow("microphone", status: monitor.microphoneStatusKey, granted: monitor.microphone == .authorized) {
                    monitor.requestMicrophone()
                }
            }
            if !monitor.accessibility {
                settingsSection("permissionTroubleshooting") {
                    Text(preferences.t("authorizationMismatch"))
                        .font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button(preferences.t("repairAccessibility")) {
                            Task { await monitor.repairAccessibility() }
                        }.disabled(monitor.repairingAccessibility)
                        Button(preferences.t("revealApp")) {
                            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                        }
                    }
                }
            }
            if let status = monitor.accessibilityRepairStatus {
                Text(preferences.t(status)).font(.callout).foregroundStyle(.secondary)
            }
        }.onAppear { monitor.refresh() }
    }
    private func permissionRow(_ key: String, status: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Text(preferences.t(key))
            Spacer()
            Label(preferences.t(status), systemImage: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary).font(.callout)
            Button(preferences.t(granted ? "manage" : "grant"), action: action)
        }
    }
}
