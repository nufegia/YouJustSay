import Foundation

/// Only an intentional first launch starts the system dialogs; login launches defer it.
@MainActor final class InitialPermissionSetup {
    private let defaults: UserDefaults
    private static let key = "initialPermissionSetupStarted"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func run(prepare: () -> Void,
             requestMicrophone: () async -> Void,
             requestAccessibility: () -> Void) async {
        guard !defaults.bool(forKey: Self.key) else { return }
        // Persist before a prompt can reactivate the app or the user quits it.
        // Denying a permission must not cause repeated prompts on every launch.
        defaults.set(true, forKey: Self.key)
        prepare()
        await requestMicrophone()
        requestAccessibility()
    }
}
