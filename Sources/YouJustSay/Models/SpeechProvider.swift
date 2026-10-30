import Foundation

enum SpeechProvider: String, CaseIterable, Identifiable, Sendable {
    case openai, doubao
    var id: String { rawValue }
    var models: [String] { self == .openai ? OpenAIModels.speech : [DoubaoSpeechModel.resourceID] }
    func modelLabel(_ model: String, language: Language) -> String {
        self == .doubao ? language.text("doubaoFlashModel") : model
    }
    func languages(model: String) -> [RecognitionLanguage] {
        switch self {
        case .doubao: return RecognitionLanguage.allCases
        case .openai: return model == "gpt-transcribe" ? Self.transcribeLanguageHints : [.automatic]
        }
    }
    // Curated common language hints, not an exhaustive model capability list.
    // Keep independent from the Doubao catalog and review with each new model.
    private static let transcribeLanguageHints: [RecognitionLanguage] = [
        .automatic, .chinese, .english, .cantonese, .japanese, .korean,
        .french, .german, .spanish, .portuguese, .italian, .russian,
        .arabic, .thai, .vietnamese, .indonesian, .malay, .filipino,
        .turkish, .dutch, .polish, .greek, .romanian, .bengali, .nepali, .ukrainian
    ]
}

struct SpeechConfiguration: Sendable {
    let provider: SpeechProvider
    let credentials: SpeechCredentials
    let model: String
}

enum OpenAIModels {
    static let speech = ["gpt-transcribe"]
    static let text = ["gpt-6.1-terra", "gpt-6-luna", "gpt-6.1-sol", "gpt-6-astra"]
    static let custom = "__custom__"
}

/// The resource actually used by the current Doubao file transcription adapter.
enum DoubaoSpeechModel {
    static let resourceID = "volc.bigasr.auc_turbo"
}
