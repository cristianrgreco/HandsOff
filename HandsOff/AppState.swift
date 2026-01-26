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
    private let loginItemManager = LoginItemManager()
    private var monitoringActivity: NSObjectProtocol?
    private var isStarting = false
    private var isUpdatingLoginItem = false
    private var isTouching = false
    private var touchReleaseStart: CFTimeInterval?
    private var cancellables = Set<AnyCancellable>()
    private let touchReleaseDebounce: CFTimeInterval = 0.3

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
                    cameraID: settings.cameraID
                )
            },
            onTrigger: { [weak alertManager, weak settings] in
                guard let settings else { return }
                alertManager?.trigger(alertType: settings.alertType)
            }
        )

        detectionEngine.setObservationHandler { [weak self] observation in
            guard let self else { return }
            self.previewHit = observation.hit
            self.previewFaceZone = observation.faceZone
            self.updateBlurOverlay(isHit: observation.hit)
            self.updateTouchState(isHit: observation.hit)
        }

        detectionEngine.setPreviewHandler { [weak self] image in
            self?.previewImage = image
        }

        blurOverlay.setIntensity(settings.blurIntensity)

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

        settings.$blurIntensity
            .sink { [weak self] value in
                self?.blurOverlay.setIntensity(value)
            }
            .store(in: &cancellables)

        if loginItemManager.isSupported {
            let enabled = loginItemManager.isEnabled()
            if settings.startAtLogin != enabled {
                settings.startAtLogin = enabled
            }
        }

        settings.$startAtLogin
            .sink { [weak self] enabled in
                guard let self else { return }
                guard self.loginItemManager.isSupported else { return }
                guard !self.isUpdatingLoginItem else { return }
                self.isUpdatingLoginItem = true
                let success = self.loginItemManager.setEnabled(enabled)
                if !success {
                    self.settings.startAtLogin = !enabled
                }
                self.isUpdatingLoginItem = false
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

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.settings.startAtLogin, self.settings.resumeMonitoringOnLaunch else { return }
            self.startMonitoring()
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
            self.resetTouchState()
            self.settings.resumeMonitoringOnLaunch = true
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
        alertManager.stopContinuous()
        settings.resumeMonitoringOnLaunch = false
        resetTouchState()
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

    private func updateTouchState(isHit: Bool) {
        guard isMonitoring else { return }
        let now = CACurrentMediaTime()
        updateContinuousSound(isHit: isHit)

        if isHit {
            touchReleaseStart = nil
            if !isTouching {
                isTouching = true
                stats.recordAlert()
            }
        } else if isTouching {
            if let touchReleaseStart {
                if now - touchReleaseStart >= touchReleaseDebounce {
                    isTouching = false
                    self.touchReleaseStart = nil
                }
            } else {
                touchReleaseStart = now
            }
        }
    }

    private func updateContinuousSound(isHit: Bool) {
        guard settings.alertType.usesSound else {
            alertManager.stopContinuous()
            return
        }
        if isHit {
            alertManager.startContinuous()
        } else {
            alertManager.stopContinuous()
        }
    }

    private func resetTouchState() {
        isTouching = false
        touchReleaseStart = nil
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
