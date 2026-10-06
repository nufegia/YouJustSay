import Foundation

enum RecognitionLanguage: String, CaseIterable, Identifiable {
    case automatic = "", chinese = "zh-CN", english = "en-US", cantonese = "yue-CN"
    case japanese = "ja-JP", korean = "ko-KR", french = "fr-FR", german = "de-DE"
    case spanish = "es-MX", portuguese = "pt-BR", italian = "it-IT", russian = "ru-RU"
    case arabic = "ar-SA", thai = "th-TH", vietnamese = "vi-VN", indonesian = "id-ID"
    case malay = "ms-MY", filipino = "fil-PH", turkish = "tr-TR", dutch = "nl-NL"
    case polish = "pl-PL", greek = "el-GR", romanian = "ro-RO", bengali = "bn-BD"
    case nepali = "ne-NP", ukrainian = "uk-UA"
    var id: String { rawValue }
    var apiValue: String { rawValue }
    func name(in language: Language) -> String {
        if self == .automatic { return language.text("automatic") }
        let resolved = language == .automatic ? Language.initial : language
        return Locale(identifier: resolved.rawValue).localizedString(forIdentifier: rawValue) ?? rawValue
    }
}
enum ChinesePreference: String, CaseIterable, Identifiable {
    case automatic, simplified, traditional
    var id: String { rawValue }
    func apply(to text: String) -> String {
        switch self {
        case .automatic: return text
        case .simplified: return text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
        case .traditional: return text.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) ?? text
        }
    }
}
