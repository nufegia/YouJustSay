import Foundation

/// A single versioned Keychain item owns all credentials for the application.
struct CredentialVault {
    static let account = "credentials.v1"
    let read: (String) throws -> Data?
    let write: (String, Data) throws -> Void

    private struct Payload: Codable {
        let version: Int
        let values: [String: String]
    }

    func load() throws -> [String: String] {
        if let data = try read(Self.account) {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            guard payload.version == 1 else { throw AppFailure.message("keychain") }
            return payload.values
        }
        return [:]
    }

    func save(_ values: [String: String]) throws {
        // An empty payload clears all saved keys without changing the item identity.
        let payload = Payload(version: 1, values: values.filter { !$0.value.isEmpty })
        try write(Self.account, JSONEncoder().encode(payload))
    }
}
