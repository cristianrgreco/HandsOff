import Foundation
import ServiceManagement

final class LoginItemManager {
    var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                return false
            }
        }
        return false
    }
}
