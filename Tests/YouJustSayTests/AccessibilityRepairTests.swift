import XCTest
@testable import YouJustSay

final class AccessibilityRepairTests: XCTestCase {
    func testRepairOnlyResetsThisAppsAccessibility() async throws {
        let result = try await AccessibilityRepair.reset(bundleID: "app.youjustsay.native") { arguments in
            XCTAssertEqual(arguments, ["reset", "Accessibility", "app.youjustsay.native"])
            return true
        }
        XCTAssertTrue(result)
    }

    func testMissingOrUnexpectedIdentityNeverRunsReset() async throws {
        for identifier in [nil, "com.apple.Terminal", ""] as [String?] {
            let result = try await AccessibilityRepair.reset(bundleID: identifier) { _ in
                XCTFail("Must not reset another app or all apps")
                return true
            }
            XCTAssertFalse(result)
        }
    }

    func testFailedResetIsNotReportedAsSuccess() async throws {
        let result = try await AccessibilityRepair.reset(bundleID: "app.youjustsay.native") { _ in false }
        XCTAssertFalse(result)
        do {
            _ = try await AccessibilityRepair.reset(bundleID: "app.youjustsay.native") { _ in
                throw CocoaError(.executableNotLoadable)
            }
            XCTFail("Launch failure must propagate")
        } catch { XCTAssertTrue(error is CocoaError) }
    }
}
