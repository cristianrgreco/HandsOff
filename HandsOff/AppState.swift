import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

final class AppState: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published var lastError: DetectionStartError?
    @Published var previewHit = false
    @Published var previewFaceZone: CGRect?
    @Published var previewImage: CGImage?

    let settings: SettingsStore
    let stats: StatsStore
    let cameraStore: CameraStore

    private let alertManager: AlertManager
    private let detectionEngine: DetectionEngine
    private let blurOverlay = BlurOverlayController()
    private var monitoringActivity: NSObjectProtocol?
    private var isStarting = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settings = SettingsStore()
        let stats = StatsStore()
        let cameraStore = CameraStore()
        let alertManager = AlertManager()

        self.settings = settings
        self.stats = stats
        self.cameraStore = cameraStore
        self.alertManager = alertManager
        self.detectionEngine = DetectionEngine(
            settingsProvider: {
                DetectionSettings(
                    sensitivity: settings.sensitivity,
                    cooldownSeconds: settings.cooldownSeconds,
                    cameraID: settings.cameraID
                )
            },
            onTrigger: { [weak stats, weak alertManager, weak settings] in
                if let alertType = settings?.alertType {
                    alertManager?.trigger(alertType: alertType)
                }
                DispatchQueue.main.async {
                    stats?.recordAlert()
                }
            }
        )

        detectionEngine.setObservationHandler { [weak self] observation in
            guard let self else { return }
            self.previewHit = observation.hit
            self.previewFaceZone = observation.faceZone
            self.updateBlurOverlay(isHit: observation.hit)
        }

        detectionEngine.setPreviewHandler { [weak self] image in
            self?.previewImage = image
        }

        settings.$alertType
            .sink { [weak alertManager] alertType in
                if alertType.usesBanner {
                    alertManager?.ensureNotificationAuthorization()
                }
            }
            .store(in: &cancellables)

        settings.$blurOnTouch
            .sink { [weak self] enabled in
                if !enabled {
                    self?.blurOverlay.hide()
                }
            }
            .store(in: &cancellables)

        cameraStore.$devices
            .sink { [weak self] _ in
                guard let self else { return }
                guard !self.isMonitoring, !self.isStarting else { return }
                guard !self.cameraStore.devices.isEmpty else { return }
                let storedID = self.settings.cameraID
                let isStoredAvailable = storedID.flatMap { id in
                    self.cameraStore.devices.first(where: { $0.uniqueID == id })
                } != nil
                guard storedID == nil || !isStoredAvailable else { return }
                self.settings.cameraID = self.cameraStore.preferredDeviceID(storedID: storedID)
            }
            .store(in: &cancellables)

        settings.$cameraID
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.isMonitoring, !self.isStarting else { return }
                self.restartMonitoring()
            }
            .store(in: &cancellables)

        if settings.cameraID == nil {
            settings.cameraID = cameraStore.preferredDeviceID(storedID: nil)
        }
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard !isMonitoring, !isStarting else { return }
        if settings.cameraID == nil {
            cameraStore.refresh()
            settings.cameraID = cameraStore.preferredDeviceID(storedID: nil)
        }
        lastError = nil
        isStarting = true
        detectionEngine.start { [weak self] error in
            guard let self else { return }
            self.isStarting = false
            if let error {
                self.isMonitoring = false
                self.lastError = error
                return
            }

            self.isMonitoring = true
            self.stats.beginMonitoring()
            self.beginMonitoringActivity()
        }
    }

    func stopMonitoring() {
        isStarting = false
        detectionEngine.stop()
        stats.endMonitoring()
        endMonitoringActivity()
        blurOverlay.hide()
        isMonitoring = false
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    func setPreviewEnabled(_ enabled: Bool) {
        detectionEngine.setPreviewEnabled(enabled)
        if !enabled {
            previewImage = nil
        }
    }

    private func updateBlurOverlay(isHit: Bool) {
        guard isMonitoring, settings.blurOnTouch else {
            blurOverlay.hide()
            return
        }
        if isHit {
            blurOverlay.show()
        } else {
            blurOverlay.hide()
        }
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func beginMonitoringActivity() {
        guard monitoringActivity == nil else { return }
        monitoringActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "HandsOff monitoring"
        )
    }

    private func endMonitoringActivity() {
        guard let monitoringActivity else { return }
        ProcessInfo.processInfo.endActivity(monitoringActivity)
        self.monitoringActivity = nil
    }
}
