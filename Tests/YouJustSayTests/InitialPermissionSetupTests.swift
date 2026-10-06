import XCTest
@testable import YouJustSay

final class InitialPermissionSetupTests: XCTestCase {
    @MainActor func testRequestsInOrderAndDoesNotRepeatAcrossLaunches() async {
        let name = "YouJustSay.PermissionTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var events: [String] = []
        let setup = InitialPermissionSetup(defaults: defaults)
        await setup.run(prepare: { events.append("prepare") }, requestMicrophone: {
            events.append("microphone")
            // A reentrant activation while a system dialog is open must not restart it.
            await setup.run(prepare: { events.append("duplicate") }, requestMicrophone: {}, requestAccessibility: {})
        }, requestAccessibility: { events.append("accessibility") })
        let nextLaunch = InitialPermissionSetup(defaults: defaults)
        await nextLaunch.run(prepare: { events.append("duplicate") }, requestMicrophone: {}, requestAccessibility: {})
        XCTAssertEqual(events, ["prepare", "microphone", "accessibility"])
    }
}
