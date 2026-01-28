import AVFoundation
import Combine
import Foundation

struct CameraDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let isExternal: Bool
}

protocol CameraStoreType: ObservableObject {
    var devices: [CameraDeviceInfo] { get }
    var devicesPublisher: Published<[CameraDeviceInfo]>.Publisher { get }
    func refresh()
    func preferredDeviceID(storedID: String?) -> String?
}

final class CameraStore: ObservableObject, CameraStoreType {
    @Published private(set) var devices: [CameraDeviceInfo] = []

    var devicesPublisher: Published<[CameraDeviceInfo]>.Publisher { $devices }

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
        devices = discovery.devices
            .filter { $0.isConnected }
            .map { device in
                CameraDeviceInfo(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isExternal: device.deviceType == .externalUnknown
                )
            }
    }

    func preferredDeviceID(storedID: String?) -> String? {
        Self.preferredDeviceID(storedID: storedID, devices: devices)
    }

    static func preferredDeviceID(storedID: String?, devices: [CameraDeviceInfo]) -> String? {
        if let storedID, devices.contains(where: { $0.id == storedID }) {
            return storedID
        }
        if let external = devices.first(where: { $0.isExternal }) {
            return external.id
        }
        return devices.first?.id
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

final class AnyCameraStore: ObservableObject, CameraStoreType {
    @Published private(set) var devices: [CameraDeviceInfo]
    private let refreshHandler: () -> Void
    private let preferredHandler: (String?) -> String?
    private var cancellable: AnyCancellable?

    init<Store: CameraStoreType>(_ store: Store) {
        self.devices = store.devices
        self.refreshHandler = store.refresh
        self.preferredHandler = store.preferredDeviceID
        self.cancellable = store.devicesPublisher
            .sink { [weak self] devices in
                self?.devices = devices
            }
    }

    var devicesPublisher: Published<[CameraDeviceInfo]>.Publisher { $devices }

    func refresh() {
        refreshHandler()
    }

    func preferredDeviceID(storedID: String?) -> String? {
        preferredHandler(storedID)
    }
}
