import Foundation

enum RecognitionLanguage: String, CaseIterable, Identifiable {
    case automatic = "", chinese = "zh-CN", english = "en-US", cantonese = "yue-CN"
    case japanese = "ja-JP", korean = "ko-KR", french = "fr-FR", german = "de-DE"
    case spanish = "es-MX", portuguese = "pt-BR", italian = "it-IT", russian = "ru-RU"
    case arabic = "ar-SA", thai = "th-TH", vietnamese = "vi-VN", indonesian = "id-ID"
    case malay = "ms-MY", filipino = "fil-PH", turkish = "tr-TR", dutch = "nl-NL"
    case polish = "pl-PL", greek = "el-GR", romanian = "ro-RO", bengali = "bn-BD"
    case nepali = "ne-NP", ukrainian = "uk-UA"
    case geminiafZA = "af-ZA"
    case geminiamET = "am-ET"
    case geminihyAM = "hy-AM"
    case geminiasIN = "as-IN"
    case geminiazAZ = "az-AZ"
    case geminibeBY = "be-BY"
    case geminibnIN = "bn-IN"
    case geminibsBA = "bs-BA"
    case geminibgBG = "bg-BG"
    case geminirupBG = "rup-BG"
    case geminimyMM = "my-MM"
    case geminicaES = "ca-ES"
    case geminiceb = "ceb"
    case geminikmKH = "km-KH"
    case geminihrHR = "hr-HR"
    case geminicsCZ = "cs-CZ"
    case geminidaDK = "da-DK"
    case geminienGB = "en-GB"
    case geminienIN = "en-IN"
    case geminietEE = "et-EE"
    case geminifaIR = "fa-IR"
    case geminifiFI = "fi-FI"
    case geminiglES = "gl-ES"
    case geminikaGE = "ka-GE"
    case geminiguIN = "gu-IN"
    case geminihaNG = "ha-NG"
    case geminiheIL = "he-IL"
    case geminihiIN = "hi-IN"
    case geminihuHU = "hu-HU"
    case geminiisIS = "is-IS"
    case geminijvID = "jv-ID"
    case geminikeaCV = "kea-CV"
    case geminiknIN = "kn-IN"
    case geminikkKZ = "kk-KZ"
    case geminikyKG = "ky-KG"
    case geminilvLV = "lv-LV"
    case geminilnCD = "ln-CD"
    case geminiltLT = "lt-LT"
    case geminimkMK = "mk-MK"
    case geminimlIN = "ml-IN"
    case geminimtMT = "mt-MT"
    case geminimrIN = "mr-IN"
    case geminimnMN = "mn-MN"
    case gemininbNO = "nb-NO"
    case geminiorIN = "or-IN"
    case geminiptPT = "pt-PT"
    case geminipaIN = "pa-IN"
    case geminipaGuruIN = "pa-Guru-IN"
    case geminisrRS = "sr-RS"
    case geminisdArabIN = "sd-Arab-IN"
    case geminiskSK = "sk-SK"
    case geminislSI = "sl-SI"
    case geminiesUS = "es-US"
    case geminiswKE = "sw-KE"
    case geminisvSE = "sv-SE"
    case geminitgTJ = "tg-TJ"
    case geminiteIN = "te-IN"
    case geminiuzUZ = "uz-UZ"
    var id: String { rawValue }
    var apiValue: String { rawValue }
    var geminiCode: String {
        switch self {
        case .chinese: "cmn-Hans-CN"
        case .cantonese: "yue-Hant-HK"
        case .arabic: "ar-EG"
        case .spanish: "es-419"
        default: rawValue
        }
    }
    var openAICode: String {
        if self == .filipino { return "tl" }
        return String(rawValue.split(separator: "-").first ?? "")
    }
    func name(in language: Language, provider: SpeechProvider) -> String {
        if provider == .gemini, self != .automatic {
            let resolved = language == .automatic ? Language.initial : language
            let code = geminiCode
            let label = Locale(identifier: resolved.rawValue).localizedString(forIdentifier: code) ?? code
            return "\(label) · \(code)"
        }
        if provider == .doubao || self == .automatic { return name(in: language) }
        let resolved = language == .automatic ? Language.initial : language
        return Locale(identifier: resolved.rawValue).localizedString(forLanguageCode: openAICode) ?? openAICode
    }
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
