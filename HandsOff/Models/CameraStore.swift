import AVFoundation
import Foundation

final class CameraStore: ObservableObject {
    @Published private(set) var devices: [AVCaptureDevice] = []

    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        observeDeviceChanges()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func refresh() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        devices = discovery.devices.filter { $0.isConnected }
    }

    func preferredDeviceID(storedID: String?) -> String? {
        if let storedID, devices.contains(where: { $0.uniqueID == storedID }) {
            return storedID
        }
        if let external = devices.first(where: { $0.deviceType == .externalUnknown }) {
            return external.uniqueID
        }
        return devices.first?.uniqueID
    }

    private func observeDeviceChanges() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: .AVCaptureDeviceWasConnected,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )
        observers.append(
            center.addObserver(
                forName: .AVCaptureDeviceWasDisconnected,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )
    }
}
