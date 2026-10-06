import Foundation

enum TextProvider: String, CaseIterable, Identifiable {
    case ark, custom
    var id: String { rawValue }
    var defaultModel: String { switch self { case .ark: "doubao-seed-2-1-lite-260915"; case .custom: "" } }
    var baseURL: String { switch self { case .ark: "https://ark.cn-beijing.volces.com/api/v3"; case .custom: "" } }
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
        components.path = "/" + (path.isEmpty ? "" : path + "/") + "chat/completions"
        guard let url = components.url else { throw AppFailure.message("invalidEndpoint") }
        return url
    }
}
