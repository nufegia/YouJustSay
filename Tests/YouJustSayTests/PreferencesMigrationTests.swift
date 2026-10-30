import XCTest
@testable import YouJustSay

final class PreferencesMigrationTests: XCTestCase {
    @MainActor private func withPreferences(_ body: (UserDefaults, CredentialStore) throws -> Void) rethrows {
        let suite = "Migration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = CredentialStore(read: { _ in [:] }, write: { _ in })
        try body(defaults, credentials)
    }

    @MainActor func testFreshInstallUsesOpenAIAcrossLaunches() {
        withPreferences { defaults, credentials in
            for _ in 0..<2 {
                let prefs = Preferences(defaults: defaults, credentials: credentials)
                XCTAssertEqual(prefs.speechProvider, .openai)
                XCTAssertEqual(prefs.provider, .openai)
            }
        }
    }

    @MainActor func testOldDefaultSetupMigratesToDoubaoAndArk() {
        withPreferences { defaults, credentials in
            defaults.set(true, forKey: "initialPermissionSetupStarted")
            defaults.set("zh-CN", forKey: "recognitionLanguage")
            for _ in 0..<2 {
                let prefs = Preferences(defaults: defaults, credentials: credentials)
                XCTAssertEqual(prefs.speechProvider, .doubao)
                XCTAssertEqual(prefs.provider, .ark)
                XCTAssertEqual(prefs.speechLanguages["doubao"], "zh-CN")
            }
        }
    }

    @MainActor func testOldCustomTextProviderIsPreserved() {
        withPreferences { defaults, credentials in
            defaults.set("custom", forKey: "provider")
            defaults.set(["custom": "my-model"], forKey: "providerModels")
            let prefs = Preferences(defaults: defaults, credentials: credentials)
            XCTAssertEqual(prefs.speechProvider, .doubao)
            XCTAssertEqual(prefs.provider, .custom)
            XCTAssertEqual(prefs.model, "my-model")
        }
    }

    @MainActor func testExplicitOpenAISpeechChoiceIsNeverMigrated() {
        withPreferences { defaults, credentials in
            defaults.set(true, forKey: "initialPermissionSetupStarted")
            defaults.set("openai", forKey: "speechProvider")
            let prefs = Preferences(defaults: defaults, credentials: credentials)
            XCTAssertEqual(prefs.speechProvider, .openai)
        }
    }

    @MainActor func testCustomModelSurvivesReselectionPresetAndRelaunch() {
        withPreferences { defaults, credentials in
            let prefs = Preferences(defaults: defaults, credentials: credentials)
            for provider in [TextProvider.openai, .ark] {
                prefs.provider = provider
                prefs.textModelChoice = TextProvider.customModelChoice
                prefs.model = "custom-" + provider.rawValue
                prefs.textModelChoice = TextProvider.customModelChoice
                XCTAssertEqual(prefs.model, "custom-" + provider.rawValue)
                prefs.textModelChoice = provider.defaultModel
            }
            let restored = Preferences(defaults: defaults, credentials: credentials)
            for provider in [TextProvider.openai, .ark] {
                restored.provider = provider
                restored.textModelChoice = TextProvider.customModelChoice
                XCTAssertEqual(restored.model, "custom-" + provider.rawValue)
            }
        }
    }

    @MainActor func testExistingCustomModelIsRememberedBeforePresetSwitch() {
        withPreferences { defaults, credentials in
            defaults.set("ark", forKey: "provider")
            defaults.set(["ark": "ep-existing"], forKey: "providerModels")
            let prefs = Preferences(defaults: defaults, credentials: credentials)
            prefs.textModelChoice = TextProvider.ark.defaultModel
            prefs.textModelChoice = TextProvider.customModelChoice
            XCTAssertEqual(prefs.model, "ep-existing")
        }
    }
}
