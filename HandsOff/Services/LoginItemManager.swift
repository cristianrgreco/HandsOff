import Foundation
import ServiceManagement

enum LoginItemStatus {
    case enabled
    case disabled
}

protocol LoginItemServiceType {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

@available(macOS 13.0, *)
struct MainAppLoginItemService: LoginItemServiceType {
    var status: LoginItemStatus {
        SMAppService.mainApp.status == .enabled ? .enabled : .disabled
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class LoginItemManager {
    private let supportsLoginItems: () -> Bool
    private let service: LoginItemServiceType?

    init(
        supportsLoginItems: @escaping () -> Bool = LoginItemManager.defaultSupportsLoginItems,
        service: LoginItemServiceType? = LoginItemManager.defaultService()
    ) {
        self.supportsLoginItems = supportsLoginItems
        self.service = service
    }

    var isSupported: Bool {
        supportsLoginItems()
    }

    func isEnabled() -> Bool {
        guard supportsLoginItems(), let service else {
            return false
        }
        return service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        guard supportsLoginItems(), let service else {
            return false
        }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    private static func defaultSupportsLoginItems() -> Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    private static func defaultService() -> LoginItemServiceType? {
        if #available(macOS 13.0, *) {
            return MainAppLoginItemService()
        }
        return nil
    }
}
