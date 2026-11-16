import Foundation

enum GeminiClient {
    static func request(key: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")
        request.setValue("2026-05-20", forHTTPHeaderField: "Api-Revision")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = body
        body["store"] = false
        body["stream"] = false
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func speechRequest(audio: Data, key: String, model: String, language: RecognitionLanguage = .automatic) throws -> URLRequest {
        guard model == GeminiSpeechModel.id, GeminiSpeechModel.languages.contains(language) else { throw AppFailure.message("invalidEndpoint") }
        guard !audio.isEmpty else { throw AppFailure.message("empty") }
        // Keep the base64 JSON payload below the 100 MB inline request limit.
        guard audio.count < 70_000_000 else { throw AppFailure.message("geminiAudioSize") }
        return try request(key: key, body: [
            "model": model,
            "input": [["type": "audio", "mime_type": "audio/wav", "data": audio.base64EncodedString()]],
            "generation_config": ["transcription_config": ["mode": ["type": "verbatim"], "language_codes": language == .automatic ? [] : [language.geminiCode]]]
        ])
    }

    static func textRequest(text: String, style: WritingStyle, configuration: TextConfiguration) throws -> URLRequest {
        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw AppFailure.message("invalidEndpoint") }
        return try request(key: configuration.key, body: [
            "model": model,
            "system_instruction": DictationEditing.instruction(style: style),
            "input": try DictationEditing.sourceMessage(text)
        ])
    }

    static func decode(_ data: Data) throws -> String {
        struct Content: Decodable { let type: String; let text: String? }
        struct Step: Decodable { let type: String; let content: [Content]? }
        struct Payload: Decodable { let status: String; let steps: [Step] }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.status == "completed" else { throw AppFailure.message("truncated") }
        let contents = payload.steps.filter { $0.type == "model_output" }.flatMap { $0.content ?? [] }
        guard !contents.contains(where: { $0.type == "refusal" }) else { throw AppFailure.message("response") }
        let text = contents.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.message("empty") }
        return text
    }
}
