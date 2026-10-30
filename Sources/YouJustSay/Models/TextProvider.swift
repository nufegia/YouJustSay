import Foundation

enum TextProvider: String, CaseIterable, Identifiable {
    case openai, ark, custom
    static let customModelChoice = "__custom__"
    var id: String { rawValue }
    var presetModels: [String] {
        switch self {
        case .openai: OpenAIModels.text
        case .ark: [defaultModel]
        case .custom: []
        }
    }
    var defaultModel: String { switch self { case .ark: "doubao-seed-2-1-lite-260915"; case .openai: "gpt-6.1-terra"; case .custom: "" } }
    var baseURL: String { switch self { case .ark: "https://ark.cn-beijing.volces.com/api/v3"; case .openai: "https://api.openai.com/v1"; case .custom: "" } }
}
struct TextConfiguration: Sendable {
    let provider: TextProvider
    let baseURL: String
    let key: String
    let model: String
    func endpoint() throws -> URL {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "https", components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else { throw AppFailure.message("invalidEndpoint") }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + (path.isEmpty ? "" : path + "/") + (provider == .openai ? "responses" : "chat/completions")
        guard let url = components.url else { throw AppFailure.message("invalidEndpoint") }
        return url
    }
}
