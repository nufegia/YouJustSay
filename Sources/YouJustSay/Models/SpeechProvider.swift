import Foundation

enum SpeechProvider: String, CaseIterable, Identifiable, Sendable {
    case openai, gemini, doubao
    var id: String { rawValue }
    var models: [String] { self == .gemini ? ["gemini-3.5-transcribe"] : (self == .openai ? OpenAIModels.speech : [DoubaoSpeechModel.resourceID]) }
    func modelLabel(_ model: String, language: Language) -> String {
        self == .doubao ? language.text("doubaoFlashModel") : model
    }
    func languages(model: String) -> [RecognitionLanguage] {
        switch self {
        case .gemini: return model == GeminiSpeechModel.id ? GeminiSpeechModel.languages : [.automatic]
        case .doubao: return Self.transcribeLanguageHints
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


// Official Gemini 3.5 Transcribe catalog, checked 2026-11-16.
// https://ai.google.dev/gemini-api/docs/transcribe#supported-languages
// en-IN appears twice in the documentation; expose it only once.
enum GeminiSpeechModel {
    static let id = "gemini-3.5-transcribe"
    static let languages: [RecognitionLanguage] = [
        .automatic,
        .geminiafZA,
        .geminiamET,
        .arabic,
        .geminihyAM,
        .geminiasIN,
        .geminiazAZ,
        .geminibeBY,
        .bengali,
        .geminibnIN,
        .geminibsBA,
        .geminibgBG,
        .geminirupBG,
        .geminimyMM,
        .cantonese,
        .geminicaES,
        .chinese,
        .geminiceb,
        .geminikmKH,
        .geminihrHR,
        .geminicsCZ,
        .geminidaDK,
        .dutch,
        .geminienGB,
        .geminienIN,
        .english,
        .geminietEE,
        .geminifaIR,
        .filipino,
        .geminifiFI,
        .french,
        .geminiglES,
        .geminikaGE,
        .german,
        .greek,
        .geminiguIN,
        .geminihaNG,
        .geminiheIL,
        .geminihiIN,
        .geminihuHU,
        .geminiisIS,
        .indonesian,
        .italian,
        .japanese,
        .geminijvID,
        .geminikeaCV,
        .geminiknIN,
        .geminikkKZ,
        .korean,
        .geminikyKG,
        .geminilvLV,
        .geminilnCD,
        .geminiltLT,
        .geminimkMK,
        .malay,
        .geminimlIN,
        .geminimtMT,
        .geminimrIN,
        .geminimnMN,
        .nepali,
        .gemininbNO,
        .geminiorIN,
        .polish,
        .portuguese,
        .geminiptPT,
        .geminipaIN,
        .geminipaGuruIN,
        .romanian,
        .russian,
        .geminisrRS,
        .geminisdArabIN,
        .geminiskSK,
        .geminislSI,
        .spanish,
        .geminiesUS,
        .geminiswKE,
        .geminisvSE,
        .geminitgTJ,
        .geminiteIN,
        .thai,
        .turkish,
        .ukrainian,
        .geminiuzUZ,
        .vietnamese
    ]
}
