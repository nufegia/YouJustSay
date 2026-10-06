#if DEBUG
import Foundation

enum LiveVerification {
    struct Credentials: Decodable { let doubao: String; let ark: String }
    static func run(audioPath: String) async -> Bool {
        do {
            guard let line = readLine() else { throw AppFailure.message("missingSpeech") }
            var saved = try Keychain.savedCredentials(allowInteraction: false)
            let credentials = try line.isEmpty ? Credentials(doubao: saved["doubao"] ?? "", ark: saved["ark"] ?? "") : JSONDecoder().decode(Credentials.self, from: Data(line.utf8))
            saved["doubao"] = credentials.doubao
            saved["ark"] = credentials.ark
            try Keychain.saveCredentials(saved)
            let client = ProviderClient()
            let audio = try Data(contentsOf: URL(fileURLWithPath: audioPath))
            let text = try await client.transcribe(audio: audio, credentials: .init(key: credentials.doubao, appID: "", token: "", legacy: false), language: .automatic)
            print("Doubao success: \(text)")
            let organized = try await client.organize(text: text, style: .clean, configuration: .init(provider: .ark, baseURL: TextProvider.ark.baseURL, key: credentials.ark, model: TextProvider.ark.defaultModel))
            print("Ark success: \(organized)")
            print("Credentials stored in macOS Keychain. No secrets logged.")
            return true
        } catch let failure as AppFailure {
            switch failure {
            case .message(let key): print("Verification failed: \(key)")
            case .provider(let provider, let code): print("Verification failed: \(provider) \(code)")
            }
        } catch { print("Verification failed: \(type(of: error))") }
        return false
    }
}
#endif
