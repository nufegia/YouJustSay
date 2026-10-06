import XCTest
@testable import YouJustSay

final class CredentialStoreTests: XCTestCase {
    @MainActor func testEditsSaveAutomaticallyWithoutExplicitFlush() async throws {
        var stored: [String: String] = [:]
        let store = CredentialStore(read: { _ in [:] }, write: { stored = $0 })
        await store.authorizeIfNeeded()
        store.set("a", for: "ark")
        store.set("latest", for: "ark")
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(stored, ["ark": "latest"])
    }

    @MainActor func testEditsDuringSaveAreWrittenInOrder() async {
        var writes: [[String: String]] = []
        var store: CredentialStore!
        store = CredentialStore(read: { _ in ["doubao": "existing", "ark": "old"] }, write: { values in
            writes.append(values)
            if writes.count == 1 { store.set("latest", for: "ark") }
        })
        await store.authorizeIfNeeded()
        store.set(" first ", for: "ark")
        let success = await store.flush()
        XCTAssertTrue(success)
        XCTAssertEqual(writes, [["doubao": "existing", "ark": "first"], ["doubao": "existing", "ark": "latest"]])
    }

    @MainActor func testDeniedReadNeverOverwritesSavedCredentials() async {
        var writes = 0
        let store = CredentialStore(read: { _ in throw AppFailure.message("keychain") }, write: { _ in writes += 1 })
        await store.authorizeIfNeeded()
        store.set("", for: "doubao")
        _ = await store.flush()
        XCTAssertFalse(store.loaded)
        XCTAssertFalse(store.loading)
        XCTAssertTrue(store.values.isEmpty)
        XCTAssertEqual(store.error, "keychainLocked")
        XCTAssertEqual(writes, 0)
    }

    @MainActor func testDeniedAuthorizationCanBeRetriedWithoutLosingSavedCredentials() async {
        var denied = true
        var resumeRead: CheckedContinuation<[String: String], Never>?
        let store = CredentialStore(read: { _ in
            if denied { throw AppFailure.message("keychain") }
            return await withCheckedContinuation { resumeRead = $0 }
        }, write: { _ in XCTFail("Authorization must not write credentials") })
        XCTAssertFalse(store.loaded)
        await store.authorizeIfNeeded()
        XCTAssertFalse(store.loaded)
        denied = false
        let retry = Task { await store.authorizeIfNeeded() }
        while resumeRead == nil { await Task.yield() }
        XCTAssertTrue(store.loading)
        XCTAssertFalse(store.loaded)
        store.set("replacement", for: "ark")
        XCTAssertTrue(store.values.isEmpty)
        resumeRead?.resume(returning: ["ark": "saved"])
        await retry.value
        XCTAssertTrue(store.loaded)
        XCTAssertFalse(store.loading)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.values["ark"], "saved")
    }

    @MainActor func testFailedWriteRetainsLatestEditForRetry() async {
        var fail = true
        var stored: [String: String] = [:]
        let store = CredentialStore(read: { _ in ["ark": "old"] }, write: { values in
            if fail { throw AppFailure.message("keychain") }
            stored = values
        })
        await store.authorizeIfNeeded()
        store.set("new", for: "ark")
        let first = await store.flush()
        XCTAssertFalse(first)
        XCTAssertEqual(store.values["ark"], "new")
        XCTAssertEqual(store.error, "credentialSyncFailed")
        fail = false
        await store.authorizeIfNeeded()
        XCTAssertEqual(stored["ark"], "new")
        XCTAssertNil(store.error)
    }

    @MainActor func testAutomaticLoadDoesNotSaveAndAuthorizationContinuesIt() async {
        var allowed: [Bool] = []
        let store = CredentialStore(read: { interactive in
            allowed.append(interactive)
            if !interactive { throw AppFailure.message("keychain") }
            return ["ark": "existing"]
        }, write: { _ in XCTFail("Loading must not save empty fields") })
        store.load()
        await store.authorizeIfNeeded()
        XCTAssertEqual(allowed, [false, true])
        XCTAssertEqual(store.values["ark"], "existing")
        XCTAssertTrue(store.loaded)
    }
}
