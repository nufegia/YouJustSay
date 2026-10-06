import Foundation
import Security
import LocalAuthentication

enum Keychain {
    private static let interactionLock = NSLock()
    static let service = "app.youjustsay.native.credentials"

    static func savedCredentials(allowInteraction: Bool) throws -> [String: String] {
        try withInteraction(allowInteraction) {
            try CredentialVault(
                read: { try readItem($0, allowInteraction: allowInteraction) },
                write: writeItem
            ).load()
        }
    }

    static func saveCredentials(_ values: [String: String]) throws {
        try withInteraction(true) {
            try CredentialVault(read: { _ in nil }, write: writeItem).save(values)
        }
    }

    private static func withInteraction<T>(_ allowed: Bool, body: () throws -> T) rethrows -> T {
        interactionLock.lock()
        defer { interactionLock.unlock() }
        // File-based Keychain ACL prompts also require the legacy interaction flag.
        var previousInteraction = DarwinBoolean(true)
        if !allowed {
            SecKeychainGetUserInteractionAllowed(&previousInteraction)
            SecKeychainSetUserInteractionAllowed(false)
        }
        defer { if !allowed { SecKeychainSetUserInteractionAllowed(previousInteraction.boolValue) } }
        return try body()
    }

    private static func readItem(_ account: String, allowInteraction: Bool) throws -> Data? {
        var query = base(account)
        if !allowInteraction {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw AppFailure.message("keychain") }
        return data
    }

    private static func writeItem(_ account: String, data: Data) throws {
        let query = base(account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "YouJustSay · API keys"
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AppFailure.message("keychain") }
        } else if status != errSecSuccess { throw AppFailure.message("keychain") }
    }

    private static func base(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}
