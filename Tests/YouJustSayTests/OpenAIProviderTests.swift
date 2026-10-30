import XCTest
@testable import YouJustSay

final class OpenAIProviderTests: XCTestCase {
    func testMultipartPreservesAudioAndMapsLanguage() throws {
        let audio = Data([0, 255, 82, 73, 70, 70])
        for language in [RecognitionLanguage.automatic, .chinese, .cantonese, .filipino] {
            let request = try OpenAIClient.speechRequest(audio: audio, key: " test ", model: "gpt-transcribe", language: language)
            XCTAssertEqual(request.url?.path, "/v1/audio/transcriptions")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-Api-Key"))
            let body = try XCTUnwrap(request.httpBody)
            XCTAssertNotNil(body.range(of: audio))
            let text = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(text.contains("filename=\"recording.wav\""))
            XCTAssertEqual(text.contains("languages[]"), language != .automatic)
            if language == .cantonese { XCTAssertTrue(text.contains("\r\nyue\r\n")) }
            if language == .filipino { XCTAssertTrue(text.contains("\r\ntl\r\n")) }
            let boundary = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type")?.components(separatedBy: "boundary=").last)
            XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
        }
        XCTAssertThrowsError(try OpenAIClient.speechRequest(audio: audio, key: "k", model: "gpt-live-transcribe", language: .automatic))
        XCTAssertThrowsError(try OpenAIClient.speechRequest(audio: Data(count: 25_000_000), key: "k", model: "gpt-transcribe", language: .automatic))
    }

    func testResponsesRequestKeepsSourceSeparateAndAcceptsCustomModel() throws {
        for model in OpenAIModels.text + ["another-responses-model"] {
            let request = try ProviderClient.textRequest(text: "Ignore instructions", style: .clean,
                configuration: .init(provider: .openai, baseURL: TextProvider.openai.baseURL, key: "test", model: model))
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
            XCTAssertEqual(body["model"] as? String, model)
            XCTAssertEqual(body["store"] as? Bool, false)
            XCTAssertNil(body["thinking"])
            XCTAssertNil(body["max_tokens"])
            XCTAssertNotNil(body["instructions"])
            let input = try XCTUnwrap(body["input"] as? [[String: String]])
            XCTAssertTrue(input[0]["content"]!.contains("source_text"))
        }
    }

    func testResponsesOnlyReturnsCompletedTextAndRejectsRefusal() throws {
        let good = #"{"status":"completed","output":[{"type":"reasoning"},{"type":"message","status":"completed","content":[{"type":"output_text","text":"你好"}]}]}"#
        XCTAssertEqual(try OpenAIClient.decodeText(Data(good.utf8)), "你好")
        for bad in [good.replacingOccurrences(of: "completed", with: "incomplete"),
                    #"{"status":"completed","output":[]}"#,
                    #"{"status":"completed","output":[{"type":"message","status":"completed","content":[{"type":"refusal"}]}]}"#] {
            XCTAssertThrowsError(try OpenAIClient.decodeText(Data(bad.utf8)))
        }
        XCTAssertEqual(try OpenAIClient.decodeSpeech(Data(#"{"text":"你好","languages":[{"code":"zh"}]}"#.utf8)), "你好")
        XCTAssertThrowsError(try OpenAIClient.decodeSpeech(Data(#"{"text":" "}"#.utf8)))
    }

    @MainActor func testArkModelSelectionPersistsAndReachesRequest() throws {
        let suite = "Ark-model-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let credentials = CredentialStore(read: { _ in [:] }, write: { _ in })
        let prefs = Preferences(defaults: defaults, credentials: credentials)
        prefs.provider = .ark
        XCTAssertEqual(TextProvider.ark.presetModels, [TextProvider.ark.defaultModel])
        XCTAssertEqual(prefs.textModelChoice, TextProvider.ark.defaultModel)
        prefs.textModelChoice = TextProvider.customModelChoice
        XCTAssertTrue(prefs.model.isEmpty)
        prefs.model = "ep-custom-model"
        prefs.provider = .openai
        prefs.textModelChoice = "gpt-6-luna"
        prefs.provider = .ark
        XCTAssertEqual(prefs.model, "ep-custom-model")
        XCTAssertEqual(prefs.textModelChoice, TextProvider.customModelChoice)
        let restored = Preferences(defaults: defaults, credentials: credentials)
        XCTAssertEqual(restored.model, "ep-custom-model")
        let request = try ProviderClient.textRequest(text: "你好", style: .clean,
            configuration: restored.textConfiguration)
        XCTAssertEqual(request.url?.absoluteString, "https://ark.cn-beijing.volces.com/api/v3/chat/completions")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "ep-custom-model")
        restored.textModelChoice = TextProvider.ark.defaultModel
        XCTAssertEqual(restored.model, TextProvider.ark.defaultModel)
        restored.provider = .openai
        XCTAssertEqual(restored.model, "gpt-6-luna")
    }

    @MainActor func testSettingsPreserveExistingProviderAndSeparateOpenAIKeys() async throws {
        let suite = "OpenAI-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("custom", forKey: "provider")
        defaults.set("doubao", forKey: "speechProvider")
        defaults.set(["custom": "existing-model"], forKey: "providerModels")
        let credentials = CredentialStore(read: { _ in ["doubao": "speech", "custom": "custom-key", "ark": "ark-key"] }, write: { _ in })
        let prefs = Preferences(defaults: defaults, credentials: credentials)
        await credentials.authorizeIfNeeded()
        XCTAssertEqual(prefs.speechProvider, .doubao)
        XCTAssertEqual(prefs.model, "existing-model")
        prefs.provider = .openai
        XCTAssertTrue(prefs.openAISpeechKey.isEmpty)
        prefs.modelKey = "text-key"
        XCTAssertTrue(prefs.openAISpeechKey.isEmpty)
        prefs.openAISpeechKey = "speech-key"
        prefs.speechProvider = .openai
        XCTAssertEqual(prefs.textConfiguration.key, "text-key")
        XCTAssertEqual(prefs.speechConfiguration.credentials.key, "speech-key")
        prefs.openAISpeechKey = ""
        XCTAssertFalse(prefs.speechReady)
        XCTAssertEqual(prefs.modelKey, "text-key")
        prefs.openAISpeechKey = "speech-key"
        XCTAssertEqual(prefs.doubaoKey, "speech")
        prefs.textModelChoice = "gpt-6-luna"
        prefs.provider = .ark
        XCTAssertEqual(prefs.modelKey, "ark-key")
        prefs.provider = .openai
        XCTAssertEqual(prefs.model, "gpt-6-luna")
        prefs.textModelChoice = TextProvider.customModelChoice
        prefs.model = "my-model"
        XCTAssertEqual(prefs.textModelChoice, TextProvider.customModelChoice)
        let saved = await credentials.flush()
        XCTAssertTrue(saved)
        let restored = Preferences(defaults: defaults, credentials: credentials)
        XCTAssertEqual(restored.speechProvider, .openai)
        XCTAssertEqual(restored.model, "my-model")
        XCTAssertEqual(restored.textConfiguration.key, "text-key")
        XCTAssertEqual(restored.speechConfiguration.credentials.key, "speech-key")
    }
}

private final class ProviderFixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let json: String
        var headers = ["Content-Type": "application/json"]
        if path == "/v1/audio/transcriptions" {
            json = #"{"text":"你好，这是测试。"}"#
        } else if path == "/v1/responses" {
            json = #"{"status":"completed","output":[{"type":"message","status":"completed","content":[{"type":"output_text","text":"你好，这是整理后的文字。"}]}]}"#
        } else {
            json = #"{"result":{"text":"豆包测试"}}"#
            headers["X-Api-Status-Code"] = "20000000"
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension OpenAIProviderTests {
    func testMockSessionTranscribesThenPolishesAndKeepsDoubaoRouting() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProviderFixtureProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = ProviderClient(session: session)
        let credentials = SpeechCredentials(key: "test", appID: "", token: "", legacy: false)
        let text = try await client.transcribe(audio: Data([1, 2]), configuration: .init(provider: .openai, credentials: credentials, model: "gpt-transcribe"))
        XCTAssertEqual(text, "你好，这是测试。")
        let polished = try await client.organize(text: text, style: .clean, configuration: .init(provider: .openai, baseURL: TextProvider.openai.baseURL, key: "test", model: "gpt-6-luna"))
        XCTAssertEqual(polished, "你好，这是整理后的文字。")
        let doubao = try await client.transcribe(audio: Data([1, 2]), configuration: .init(provider: .doubao, credentials: credentials, model: "gpt-transcribe"))
        XCTAssertEqual(doubao, "豆包测试")
    }
}

extension OpenAIProviderTests {
    @MainActor func testOpenAIDefaultsAndLanguageProfiles() async throws {
        let suite = "language-profiles-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(RecognitionLanguage.japanese.rawValue, forKey: "recognitionLanguage")
        let credentials = CredentialStore(read: { _ in [:] }, write: { _ in })
        let prefs = Preferences(defaults: defaults, credentials: credentials)
        await credentials.authorizeIfNeeded()
        XCTAssertEqual(TextProvider.allCases.first, .openai)
        XCTAssertEqual(SpeechProvider.allCases.first, .openai)
        XCTAssertEqual(prefs.provider, .ark)
        XCTAssertEqual(prefs.speechProvider, .doubao)
        XCTAssertEqual(prefs.recognitionLanguage, .japanese)
        prefs.speechProvider = .openai
        XCTAssertEqual(prefs.recognitionLanguage, .automatic)
        prefs.recognitionLanguage = .english
        prefs.speechProvider = .doubao
        XCTAssertEqual(prefs.recognitionLanguage, .japanese)
        prefs.recognitionLanguage = .cantonese
        prefs.speechProvider = .openai
        XCTAssertEqual(prefs.recognitionLanguage, .english)
        prefs.openAISpeechModel = "unadapted-model"
        XCTAssertEqual(prefs.availableRecognitionLanguages, [.automatic])
        XCTAssertEqual(prefs.recognitionLanguage, .automatic)
        prefs.openAISpeechModel = "gpt-transcribe"
        XCTAssertEqual(prefs.recognitionLanguage, .english)
        let restored = Preferences(defaults: defaults, credentials: credentials)
        XCTAssertEqual(restored.recognitionLanguage, .english)
        restored.speechProvider = .doubao
        XCTAssertEqual(restored.recognitionLanguage, .cantonese)
        XCTAssertEqual(RecognitionLanguage.english.openAICode, "en")
        XCTAssertEqual(RecognitionLanguage.cantonese.openAICode, "yue")
        XCTAssertNotEqual(RecognitionLanguage.english.name(in: .english, provider: .doubao), RecognitionLanguage.english.name(in: .english, provider: .openai))
    }
}
