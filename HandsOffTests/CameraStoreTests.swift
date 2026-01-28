import XCTest
@testable import HandsOff

final class CameraStoreTests: XCTestCase {
    func testPreferredDeviceIDUsesStoredIDIfPresent() {
        let devices = [
            CameraDeviceInfo(id: "primary", name: "Built-in", isExternal: false),
            CameraDeviceInfo(id: "external", name: "USB", isExternal: true)
        ]

        let preferred = CameraStore.preferredDeviceID(storedID: "primary", devices: devices)

        XCTAssertEqual(preferred, "primary")
    }

    func testPreferredDeviceIDFallsBackToExternal() {
        let devices = [
            CameraDeviceInfo(id: "builtIn", name: "Built-in", isExternal: false),
            CameraDeviceInfo(id: "external", name: "USB", isExternal: true)
        ]

        let preferred = CameraStore.preferredDeviceID(storedID: "missing", devices: devices)

        XCTAssertEqual(preferred, "external")
    }

    func testPreferredDeviceIDFallsBackToFirstDevice() {
        let devices = [
            CameraDeviceInfo(id: "first", name: "Built-in", isExternal: false),
            CameraDeviceInfo(id: "second", name: "Secondary", isExternal: false)
        ]

        let preferred = CameraStore.preferredDeviceID(storedID: nil, devices: devices)

        XCTAssertEqual(preferred, "first")
    }

    func testPreferredDeviceIDIsNilWhenNoDevices() {
        let preferred = CameraStore.preferredDeviceID(storedID: nil, devices: [])

        XCTAssertNil(preferred)
    }

    func testAnyCameraStoreDelegatesRefreshAndPreferredID() {
        let baseStore = TestCameraStore(devices: [
            CameraDeviceInfo(id: "first", name: "Built-in", isExternal: false)
        ])
        let anyStore = AnyCameraStore(baseStore)

        XCTAssertEqual(anyStore.preferredDeviceID(storedID: nil), "first")
        anyStore.refresh()

        XCTAssertEqual(baseStore.refreshCount, 1)
    }

    func testAnyCameraStoreUpdatesDevicesFromPublisher() {
        let baseStore = TestCameraStore(devices: [])
        let anyStore = AnyCameraStore(baseStore)
        let newDevices = [
            CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false)
        ]

        baseStore.devices = newDevices

        XCTAssertEqual(anyStore.devices, newDevices)
    }
}
