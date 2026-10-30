import Foundation
import Observation

enum SettingsTab: Hashable {
    case general, interaction, models, permissions, about
    var windowHeight: CGFloat { 620 }
}

@MainActor @Observable final class Preferences {
    var settingsTab = SettingsTab.general
    var speechLanguages: [String: String] { didSet { defaults.set(speechLanguages, forKey: "speechLanguages") } }
    private var speechLanguageProfile: String { speechProvider == .doubao ? "doubao" : "openai/" + openAISpeechModel }
    var availableRecognitionLanguages: [RecognitionLanguage] { speechProvider.languages(model: openAISpeechModel) }
    var recognitionLanguage: RecognitionLanguage {
        get {
            let selected = RecognitionLanguage(rawValue: speechLanguages[speechLanguageProfile] ?? "") ?? .automatic
            return availableRecognitionLanguages.contains(selected) ? selected : .automatic
        }
        set { speechLanguages[speechLanguageProfile] = newValue.rawValue }
    }
    var chinesePreference: ChinesePreference { didSet { defaults.set(chinesePreference.rawValue, forKey: "chinesePreference") } }
    var shortcut: Shortcut { didSet { if let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: "shortcut") } } }
    var selectionShortcut: Shortcut { didSet { if let data = try? JSONEncoder().encode(selectionShortcut) { defaults.set(data, forKey: "selectionShortcut") } } }
    var holdToTalk: Bool { didSet { defaults.set(holdToTalk, forKey: "holdToTalk") } }
    var insertion: InsertionMode { didSet { defaults.set(insertion.rawValue, forKey: "insertion") } }
    var showDock: Bool { didSet { defaults.set(showDock, forKey: "showDock") } }
    var showMenu: Bool { didSet { defaults.set(showMenu, forKey: "showMenu") } }
    var style: WritingStyle { didSet { defaults.set(style.rawValue, forKey: "style") } }
    var language: Language { didSet { defaults.set(language.rawValue, forKey: "language") } }
    var legacyAuth: Bool { didSet { defaults.set(legacyAuth, forKey: "legacyAuth") } }
    var autoOrganize: Bool { didSet { defaults.set(autoOrganize, forKey: "autoOrganize") } }
    var speechProvider: SpeechProvider { didSet { defaults.set(speechProvider.rawValue, forKey: "speechProvider") } }
    var openAISpeechModel: String { didSet { defaults.set(openAISpeechModel, forKey: "openAISpeechModel") } }
    var openAISpeechKey: String {
        get { credentials.values["openaiSpeech"] ?? "" }
        set { credentials.set(newValue, for: "openaiSpeech") }
    }
    var speechModel: String {
        get { speechProvider == .openai ? openAISpeechModel : DoubaoSpeechModel.resourceID }
        set { if speechProvider == .openai { openAISpeechModel = newValue } }
    }
    var speechConfiguration: SpeechConfiguration {
        SpeechConfiguration(provider: speechProvider,
            credentials: SpeechCredentials(key: speechProvider == .openai ? openAISpeechKey : doubaoKey,
                appID: appID, token: accessToken, legacy: legacyAuth), model: speechModel)
    }
    var textModelChoice: String {
        get { provider.presetModels.contains(model) ? model : TextProvider.customModelChoice }
        set {
            if newValue == TextProvider.customModelChoice {
                guard textModelChoice != TextProvider.customModelChoice else { return }
                model = customProviderModels[provider.rawValue] ?? ""
            } else { model = newValue }
        }
    }
    var provider: TextProvider { didSet { defaults.set(provider.rawValue, forKey: "provider") } }
    var providerModels: [String: String] { didSet { defaults.set(providerModels, forKey: "providerModels") } }
    var customProviderModels: [String: String] { didSet { defaults.set(customProviderModels, forKey: "customProviderModels") } }
    let credentials: CredentialStore
    var customURL: String { didSet { defaults.set(customURL, forKey: "customURL") } }
    var model: String {
        get { providerModels[provider.rawValue] ?? provider.defaultModel }
        set {
            let previous = model
            if !previous.isEmpty && !provider.presetModels.contains(previous) {
                customProviderModels[provider.rawValue] = previous
            }
            providerModels[provider.rawValue] = newValue
            if !newValue.isEmpty && !provider.presetModels.contains(newValue) {
                customProviderModels[provider.rawValue] = newValue
            }
        }
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
    init(defaults: UserDefaults = .standard, credentials: CredentialStore = CredentialStore()) {
        self.defaults = defaults
        self.credentials = credentials
        var savedLanguages = defaults.dictionary(forKey: "speechLanguages") as? [String: String] ?? [:]
        if savedLanguages["doubao"] == nil, let legacy = defaults.string(forKey: "recognitionLanguage") {
            savedLanguages["doubao"] = legacy
        }
        speechLanguages = savedLanguages
        chinesePreference = ChinesePreference(rawValue: defaults.string(forKey: "chinesePreference") ?? "") ?? .automatic
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .fn
        selectionShortcut = defaults.data(forKey: "selectionShortcut").flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .fnSpace
        holdToTalk = defaults.bool(forKey: "holdToTalk")
        insertion = InsertionMode(rawValue: defaults.string(forKey: "insertion") ?? "") ?? .paste
        showDock = defaults.bool(forKey: "showDock")
        showMenu = defaults.bool(forKey: "showMenu")
        style = WritingStyle(rawValue: defaults.string(forKey: "style") ?? "") ?? .basic
        language = Language(rawValue: defaults.string(forKey: "language") ?? "") ?? .automatic
        legacyAuth = defaults.bool(forKey: "legacyAuth")
        autoOrganize = defaults.bool(forKey: "autoOrganize")
        // Older versions only had Doubao speech and did not persist a provider.
        // Resolve the migration before writing any new settings; fresh installs use OpenAI.
        let legacyKeys = ["initialPermissionSetupStarted", "recognitionLanguage", "chinesePreference",
            "shortcut", "selectionShortcut", "holdToTalk", "insertion", "showDock", "showMenu",
            "style", "language", "legacyAuth", "autoOrganize", "provider", "providerModels", "customURL"]
        let upgrading = legacyKeys.contains { defaults.object(forKey: $0) != nil }
            && defaults.string(forKey: "speechProvider") == nil
        speechProvider = SpeechProvider(rawValue: defaults.string(forKey: "speechProvider") ?? "") ?? (upgrading ? .doubao : .openai)
        openAISpeechModel = defaults.string(forKey: "openAISpeechModel") ?? "gpt-transcribe"
        provider = TextProvider(rawValue: defaults.string(forKey: "provider") ?? "") ?? (upgrading ? .ark : .openai)
        providerModels = defaults.dictionary(forKey: "providerModels") as? [String: String] ?? [:]
        customProviderModels = defaults.dictionary(forKey: "customProviderModels") as? [String: String] ?? [:]
        customURL = defaults.string(forKey: "customURL") ?? ""
        defaults.set(speechProvider.rawValue, forKey: "speechProvider")
        defaults.set(provider.rawValue, forKey: "provider")
        credentials.load()
    }
    func t(_ key: String) -> String { language.text(key) }
    var speechReady: Bool {
        if speechProvider == .openai { return !openAISpeechKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && OpenAIModels.speech.contains(openAISpeechModel) }
        return legacyAuth ? !appID.isEmpty && !accessToken.isEmpty : !doubaoKey.isEmpty
    }
}
