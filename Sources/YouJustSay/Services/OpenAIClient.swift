import Foundation

/// OpenAI file transcription and Responses decoding; no subscription credentials.
enum OpenAIClient {
    static func speechRequest(audio: Data, key: String, model: String, language: RecognitionLanguage) throws -> URLRequest {
        guard OpenAIModels.speech.contains(model) else { throw AppFailure.message("invalidSpeechModel") }
        guard SpeechProvider.openai.languages(model: model).contains(language) else { throw AppFailure.message("invalidSpeechModel") }
        guard !audio.isEmpty else { throw AppFailure.message("empty") }
        guard audio.count < 25_000_000 else { throw AppFailure.message("audioTooLarge") }
        let boundary = "YouJustSay-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(key.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("model", model)
        if language != .automatic {
            field("languages[]", language.openAICode)
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(audio)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        return request
    }

    static func decodeSpeech(_ data: Data) throws -> String {
        struct Payload: Decodable { let text: String }
        let text = try JSONDecoder().decode(Payload.self, from: data).text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.message("empty") }
        return text
    }

    static func decodeText(_ data: Data) throws -> String {
        struct Payload: Decodable {
            struct Output: Decodable {
                struct Content: Decodable { let type: String; let text: String? }
                let type: String
                let status: String?
                let content: [Content]?
            }
            let status: String
            let output: [Output]
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.status == "completed" else { throw AppFailure.message("truncated") }
        var parts: [String] = []
        for output in payload.output where output.type == "message" {
            guard output.status == "completed" else { throw AppFailure.message("truncated") }
            for content in output.content ?? [] {
                if content.type == "refusal" { throw AppFailure.message("response") }
                if content.type == "output_text", let text = content.text { parts.append(text) }
            }
        }
        let text = parts.joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AppFailure.message("empty") }
        return text
    }
}
