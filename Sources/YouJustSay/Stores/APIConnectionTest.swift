import Foundation
import Observation

@MainActor @Observable final class APIConnectionTest {
    enum Result: Equatable {
        case success
        case failure(String)
        case providerFailure(String, String)
    }
    private(set) var running = false
    private(set) var result: Result?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func start(_ operation: @escaping @Sendable () async throws -> Void) {
        guard !running else { return }
        result = nil; running = true
        let token = generation
        task = Task {
            let outcome: Result
            do {
                try await operation()
                try Task.checkCancellation()
                outcome = .success
            } catch {
                guard !Task.isCancelled else { return }
                if let failure = error as? AppFailure {
                    switch failure {
                    case .message(let key): outcome = .failure(key)
                    case .provider(let provider, let code): outcome = .providerFailure(provider, code)
                    }
                } else {
                    outcome = .failure(error is DecodingError ? "response" : "network")
                }
            }
            guard token == generation else { return }
            result = outcome; running = false
        }
    }

    func reset() {
        generation = UUID(); task?.cancel(); task = nil
        running = false; result = nil
    }
}
