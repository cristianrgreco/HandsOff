import XCTest
@testable import HandsOff

final class SettingsPresentationTests: XCTestCase {
    func testCameraPlaceholderTextWhenNoDevices() {
        XCTAssertEqual(SettingsPresentation.cameraPlaceholderText(devices: []), "Camera: none detected")
    }

    func testCameraPlaceholderTextWhenDevicesPresent() {
        let devices = [CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false)]
        XCTAssertNil(SettingsPresentation.cameraPlaceholderText(devices: devices))
    }
}
