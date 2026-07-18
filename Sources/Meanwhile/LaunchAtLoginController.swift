import MeanwhileCore
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    private var service: SMAppService { .mainApp }

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginStatus {
        if enabled {
            if service.status == .notRegistered || service.status == .notFound {
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
        return status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
