import ServiceManagement
import Observation

@MainActor @Observable final class LoginItem {
    var enabled = false
    var needsApproval = false
    var error: String?
    init() { refresh() }
    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }
    func setEnabled(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = "loginFailed" }
        refresh()
    }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
