import XCTest
@testable import YouJustSay

final class CredentialVaultTests: XCTestCase {
    func testAllKeysRoundTripWithOneReadAndOneWrite() throws {
        var stored: Data?
        var reads: [String] = []
        var writes: [String] = []
        let vault = CredentialVault(read: { account in
            reads.append(account)
            return stored
        }, write: { account, data in
            writes.append(account)
            stored = data
        })
        let values = ["doubao": "speech-test", "ark": "ark-test", "custom": "custom-test"]
        try vault.save(values)
        XCTAssertEqual(try vault.load(), values)
        XCTAssertEqual(reads, [CredentialVault.account])
        XCTAssertEqual(writes, [CredentialVault.account])
        try vault.save(["doubao": "", "ark": ""])
        XCTAssertEqual(try vault.load(), [:])
    }

    func testMissingItemDoesNotReadOldKeysOrWriteAnything() throws {
        var reads: [String] = []
        let vault = CredentialVault(read: { account in
            reads.append(account)
            return nil
        }, write: { _, _ in XCTFail("Loading missing credentials must not create a new item") })
        XCTAssertEqual(try vault.load(), [:])
        XCTAssertEqual(reads, [CredentialVault.account])
    }

    func testDeniedReadAndCorruptDataDoNotOverwriteSavedKeys() {
        let denied = CredentialVault(read: { _ in throw AppFailure.message("keychain") },
                                     write: { _, _ in XCTFail("Must not write after denied access") })
        XCTAssertThrowsError(try denied.load())
        for data in [Data("invalid".utf8), Data(#"{"version":2,"values":{}}"#.utf8)] {
            let vault = CredentialVault(read: { _ in data }, write: { _, _ in XCTFail("Must not overwrite unreadable data") })
            XCTAssertThrowsError(try vault.load())
        }
    }
}
