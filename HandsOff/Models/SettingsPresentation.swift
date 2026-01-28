import Foundation

struct SettingsPresentation {
    static func cameraPlaceholderText(devices: [CameraDeviceInfo]) -> String? {
        devices.isEmpty ? "Camera: none detected" : nil
    }
}
