import Foundation

struct SpeechCredentials: Sendable {
    let key: String
    let appID: String
    let token: String
    let legacy: Bool
}

struct ProviderClient: Sendable {
    var session: URLSession = .shared
    static func testAudio() throws -> Data {
        guard let url = Bundle.module.url(forResource: "api-test", withExtension: "wav") else {
            throw AppFailure.message("response")
        }
        return try Data(contentsOf: url)
    }
    func testSpeech(credentials: SpeechCredentials) async throws {
        _ = try await transcribe(audio: Self.testAudio(), credentials: credentials)
    }
    func testText(configuration: TextConfiguration) async throws {
        _ = try await organize(text: "你好，这是一段文本整理测试。", style: .basic, configuration: configuration)
    }
    static func speechRequest(audio: Data, credentials: SpeechCredentials, language: RecognitionLanguage = .automatic) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if credentials.legacy {
            request.setValue(credentials.appID, forHTTPHeaderField: "X-Api-App-Key")
            request.setValue(credentials.token, forHTTPHeaderField: "X-Api-Access-Key")
        } else { request.setValue(credentials.key, forHTTPHeaderField: "X-Api-Key") }
        request.setValue("volc.bigasr.auc_turbo", forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Api-Request-Id")
        request.setValue("-1", forHTTPHeaderField: "X-Api-Sequence")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "user": ["uid": "youjustsay"],
            "audio": ["data": audio.base64EncodedString(), "format": "wav", "language": language.apiValue],
            "request": ["model_name": "bigmodel", "enable_itn": true, "enable_punc": true, "enable_auto_lang": language == .automatic]
        ])
        return request
    }
    func transcribe(audio: Data, credentials: SpeechCredentials, language: RecognitionLanguage = .automatic) async throws -> String {
        let (data, response) = try await session.data(for: Self.speechRequest(audio: audio, credentials: credentials, language: language))
        return try Self.decodeSpeech(data, response: response)
    }
    static func decodeSpeech(_ data: Data, response: URLResponse) throws -> String {
        let http = try validate(response, provider: "Doubao")
        guard let status = http.value(forHTTPHeaderField: "X-Api-Status-Code") else { throw AppFailure.message("response") }
        if status == "20000003" { throw AppFailure.message("empty") }
        guard status == "20000000" else { throw AppFailure.provider("Doubao", status) }
        struct Payload: Decodable { struct Result: Decodable { let text: String }; let result: Result }
        let result = try JSONDecoder().decode(Payload.self, from: data).result.text
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.message("empty") }
        return result
    }
    static func textRequest(text: String, style: WritingStyle, configuration: TextConfiguration) throws -> URLRequest {
        var request = URLRequest(url: try configuration.endpoint())
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(configuration.key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "model": configuration.model, "stream": false, "max_tokens": 8192,
            "messages": [
                ["role": "system", "content": DictationEditing.instruction(style: style)],
                ["role": "user", "content": try DictationEditing.sourceMessage(text)]
            ]
        ]
        if configuration.provider != .custom { body["thinking"] = ["type": "disabled"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    func organize(text: String, style: WritingStyle, configuration: TextConfiguration) async throws -> String {
        let (data, response) = try await session.data(for: Self.textRequest(text: text, style: style, configuration: configuration))
        _ = try Self.validate(response, provider: configuration.provider.rawValue)
        return DictationEditing.result(try Self.decodeText(data), source: text)
    }
    static func decodeText(_ data: Data) throws -> String {
        struct Payload: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
                let finish_reason: String?
            }
            let choices: [Choice]
        }
        guard let choice = try JSONDecoder().decode(Payload.self, from: data).choices.first else { throw AppFailure.message("empty") }
        guard choice.finish_reason == "stop" else { throw AppFailure.message("truncated") }
        guard let text = choice.message.content, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.message("empty") }
        return text
    }
    private static func validate(_ response: URLResponse, provider: String) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else { throw AppFailure.message("response") }
        guard (200..<300).contains(http.statusCode) else { throw AppFailure.provider(provider, "HTTP \(http.statusCode)") }
        return http
    }
}
