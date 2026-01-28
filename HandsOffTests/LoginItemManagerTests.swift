import XCTest
@testable import HandsOff

final class LoginItemManagerTests: XCTestCase {
    func testIsSupportedUsesSupportsClosure() {
        let manager = LoginItemManager(supportsLoginItems: { false }, service: nil)

        XCTAssertFalse(manager.isSupported)
    }

    func testIsEnabledReturnsFalseWhenUnsupported() {
        let service = FakeLoginItemService(status: .enabled)
        let manager = LoginItemManager(supportsLoginItems: { false }, service: service)

        XCTAssertFalse(manager.isEnabled())
        XCTAssertFalse(manager.setEnabled(true))
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testIsEnabledUsesServiceStatus() {
        let enabledService = FakeLoginItemService(status: .enabled)
        let enabledManager = LoginItemManager(supportsLoginItems: { true }, service: enabledService)
        XCTAssertTrue(enabledManager.isEnabled())

        let disabledService = FakeLoginItemService(status: .disabled)
        let disabledManager = LoginItemManager(supportsLoginItems: { true }, service: disabledService)
        XCTAssertFalse(disabledManager.isEnabled())
    }

    func testIsEnabledReturnsFalseWhenServiceMissing() {
        let manager = LoginItemManager(supportsLoginItems: { true }, service: nil)

        XCTAssertFalse(manager.isEnabled())
        XCTAssertFalse(manager.setEnabled(true))
    }

    func testSetEnabledRegistersWhenEnabled() {
        let service = FakeLoginItemService(status: .disabled)
        let manager = LoginItemManager(supportsLoginItems: { true }, service: service)

        XCTAssertTrue(manager.setEnabled(true))
        XCTAssertEqual(service.registerCount, 1)
        XCTAssertEqual(service.unregisterCount, 0)
    }

    func testSetEnabledUnregistersWhenDisabled() {
        let service = FakeLoginItemService(status: .enabled)
        let manager = LoginItemManager(supportsLoginItems: { true }, service: service)

        XCTAssertTrue(manager.setEnabled(false))
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testSetEnabledReturnsFalseOnError() {
        let service = FakeLoginItemService(status: .disabled)
        service.shouldThrow = true
        let manager = LoginItemManager(supportsLoginItems: { true }, service: service)

        XCTAssertFalse(manager.setEnabled(true))
        XCTAssertEqual(service.registerCount, 1)
    }
}

private final class FakeLoginItemService: LoginItemServiceType {
    var status: LoginItemStatus
    var shouldThrow = false
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if shouldThrow {
            throw TestError()
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if shouldThrow {
            throw TestError()
        }
        status = .disabled
    }

    private struct TestError: Error {}
}
