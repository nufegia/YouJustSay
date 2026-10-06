import Foundation
import Observation

@MainActor @Observable final class CredentialStore {
    private(set) var values: [String: String] = [:]
    private(set) var loaded = false
    private(set) var loading = false
    private(set) var error: String?
    private var dirty = false
    private var loadTask: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var writer: Task<Void, Never>?
    private let read: (Bool) async throws -> [String: String]
    private let write: ([String: String]) async throws -> Void

    init(read: @escaping (Bool) async throws -> [String: String] = { allowed in
        try await Task.detached { try Keychain.savedCredentials(allowInteraction: allowed) }.value
    }, write: @escaping ([String: String]) async throws -> Void = { values in
        try await Task.detached { try Keychain.saveCredentials(values) }.value
    }) {
        self.read = read
        self.write = write
    }

    func load() {
        guard !loading, !loaded else { return }
        loading = true
        loadTask = Task {
            defer { loading = false }
            do { values = try await read(false); loaded = true; error = nil }
            catch { self.error = "keychainLocked" }
        }
    }

    func authorizeIfNeeded() async {
        await loadTask?.value
        guard !loading else { return }
        if loaded {
            if dirty { _ = await flush() }
            return
        }
        loading = true
        defer { loading = false }
        do { values = try await read(true); loaded = true; error = nil }
        catch { self.error = "keychainLocked" }
    }

    func set(_ value: String, for account: String) {
        guard loaded, !loading, values[account] != value else { return }
        values[account] = value
        dirty = true
        debounce?.cancel()
        debounce = Task {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            _ = await flush()
        }
    }

    /// Serializes snapshots and waits for the latest edit, including edits made during a write.
    func flush() async -> Bool {
        debounce?.cancel()
        debounce = nil
        if let writer { await writer.value; return !dirty }
        guard loaded, dirty else { return !dirty }
        let task = Task {
            while dirty {
                let snapshot = values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                dirty = false
                do { try await write(snapshot); error = nil }
                catch { dirty = true; self.error = "credentialSyncFailed"; break }
            }
        }
        writer = task
        await task.value
        writer = nil
        return !dirty
    }
}
