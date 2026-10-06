import Foundation
import Observation

enum SettingsTab: Hashable {
    case general, interaction, models, permissions, about
    var windowHeight: CGFloat { 620 }
}

@MainActor @Observable final class Preferences {
    var settingsTab = SettingsTab.general
    var recognitionLanguage: RecognitionLanguage { didSet { defaults.set(recognitionLanguage.rawValue, forKey: "recognitionLanguage") } }
    var chinesePreference: ChinesePreference { didSet { defaults.set(chinesePreference.rawValue, forKey: "chinesePreference") } }
    var shortcut: Shortcut { didSet { if let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: "shortcut") } } }
    var holdToTalk: Bool { didSet { defaults.set(holdToTalk, forKey: "holdToTalk") } }
    var insertion: InsertionMode { didSet { defaults.set(insertion.rawValue, forKey: "insertion") } }
    var showDock: Bool { didSet { defaults.set(showDock, forKey: "showDock") } }
    var showMenu: Bool { didSet { defaults.set(showMenu, forKey: "showMenu") } }
    var style: WritingStyle { didSet { defaults.set(style.rawValue, forKey: "style") } }
    var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
    var legacyAuth: Bool { didSet { defaults.set(legacyAuth, forKey: "legacyAuth") } }
    var autoOrganize: Bool { didSet { defaults.set(autoOrganize, forKey: "autoOrganize") } }
    var provider: TextProvider { didSet { defaults.set(provider.rawValue, forKey: "provider") } }
    var providerModels: [String: String] { didSet { defaults.set(providerModels, forKey: "providerModels") } }
    let credentials = CredentialStore()
    var customURL: String { didSet { defaults.set(customURL, forKey: "customURL") } }
    var model: String {
        get { provider == .ark ? provider.defaultModel : providerModels[provider.rawValue] ?? provider.defaultModel }
        set { providerModels[provider.rawValue] = newValue }
    }
    var modelKey: String {
        get { credentials.values[provider.rawValue] ?? "" }
        set { credentials.set(newValue, for: provider.rawValue) }
    }
    var textConfiguration: TextConfiguration {
        TextConfiguration(provider: provider, baseURL: provider == .custom ? customURL : provider.baseURL, key: modelKey, model: model)
    }
    var doubaoKey: String {
        get { credentials.values["doubao"] ?? "" }
        set { credentials.set(newValue, for: "doubao") }
    }
    var appID: String {
        get { credentials.values["appID"] ?? "" }
        set { credentials.set(newValue, for: "appID") }
    }
    var accessToken: String {
        get { credentials.values["accessToken"] ?? "" }
        set { credentials.set(newValue, for: "accessToken") }
    }
    var credentialError: String? { credentials.error }
    var loadingCredentials: Bool { !credentials.loaded || credentials.loading }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recognitionLanguage = RecognitionLanguage(rawValue: defaults.string(forKey: "recognitionLanguage") ?? "") ?? .automatic
        chinesePreference = ChinesePreference(rawValue: defaults.string(forKey: "chinesePreference") ?? "") ?? .automatic
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .fn
        holdToTalk = defaults.bool(forKey: "holdToTalk")
        insertion = InsertionMode(rawValue: defaults.string(forKey: "insertion") ?? "") ?? .paste
        showDock = defaults.bool(forKey: "showDock")
        showMenu = defaults.bool(forKey: "showMenu")
        style = WritingStyle(rawValue: defaults.string(forKey: "style") ?? "") ?? .basic
        language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .automatic
        legacyAuth = defaults.bool(forKey: "legacyAuth")
        autoOrganize = defaults.bool(forKey: "autoOrganize")
        provider = TextProvider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .ark
        providerModels = defaults.dictionary(forKey: "providerModels") as? [String: String] ?? [:]
        customURL = defaults.string(forKey: "customURL") ?? ""
        credentials.load()
    }
    func t(_ key: String) -> String { language.text(key) }
    var speechReady: Bool { legacyAuth ? !appID.isEmpty && !accessToken.isEmpty : !doubaoKey.isEmpty }
}
