import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

final class AppState: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published private(set) var isStarting = false
    @Published private(set) var isAwaitingCamera = false
    @Published var lastError: DetectionStartError?
    @Published var previewHit = false
    @Published var previewFaceZone: CGRect?
    @Published var previewImage: CGImage?
    @Published var previewHandPoints: [CGPoint] = []
    @Published private(set) var snoozedUntil: Date?

    let settings: SettingsStore
    let stats: StatsStore
    let cameraStore: CameraStore

    private let alertManager: AlertManager
    private let blurOverlay = BlurOverlayController()
    private let loginItemManager = LoginItemManager()
    private let stateDefaults = UserDefaults.standard
    private var monitoringActivity: NSObjectProtocol?
    private var isUpdatingLoginItem = false
    private var isTouching = false
    private var touchReleaseStart: CFTimeInterval?
    private var snoozeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let touchReleaseDebounce: CFTimeInterval = 0.3
    private var resumeMonitoringWhenCameraAvailable = false
    private var deviceObservers: [NSObjectProtocol] = []
    private var frameStallTimer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    private let frameStallThreshold: CFTimeInterval = 1.2

    private lazy var detectionEngine: DetectionEngine = DetectionEngine(
        settingsProvider: { [weak self] in
            guard let self else {
                return DetectionSettings(cameraID: nil, faceZoneScale: CGFloat(SettingsStore.faceZoneBaselineScale))
            }
            return DetectionSettings(
                cameraID: self.settings.cameraID,
                faceZoneScale: CGFloat(self.settings.faceZoneScale * SettingsStore.faceZoneBaselineScale)
            )
        },
        onTrigger: { [weak self] in
            self?.handleTrigger()
        }
    )

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > Date()
    }

    init() {
        let settings = SettingsStore()
        let stats = StatsStore()
        let cameraStore = CameraStore()
        let alertManager = AlertManager()

        self.settings = settings
        self.stats = stats
        self.cameraStore = cameraStore
        self.alertManager = alertManager
        migrateResumeMonitoringStateIfNeeded()

        detectionEngine.setObservationHandler { [weak self] observation in
            guard let self else { return }
            self.previewHit = observation.hit
            self.previewFaceZone = observation.faceZone
            self.previewHandPoints = observation.handPoints
            self.updateBlurOverlay(isHit: observation.hit)
            self.updateTouchState(isHit: observation.hit)
        }

        detectionEngine.setPreviewHandler { [weak self] image in
            guard let self else { return }
            self.previewImage = image
        }

        detectionEngine.setFrameHandler { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.lastFrameTime = now
            if self.isAwaitingCamera {
                self.isAwaitingCamera = false
            }
        }

        settings.$alertBannerEnabled
            .sink { [weak alertManager] enabled in
                if enabled {
                    alertManager?.ensureNotificationAuthorization()
                }
            }
            .store(in: &cancellables)

        settings.$flashScreenOnTouch
            .sink { [weak self] enabled in
                if !enabled {
                    self?.blurOverlay.hide()
                }
            }
            .store(in: &cancellables)

        settings.$alertSoundEnabled
            .sink { [weak self] enabled in
                guard let self else { return }
                guard self.isMonitoring else { return }
                if enabled {
                    self.alertManager.prepareContinuous()
                } else {
                    self.alertManager.shutdownContinuous()
                }
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

        deviceObservers.append(
            NotificationCenter.default.addObserver(
                forName: .AVCaptureDeviceWasDisconnected,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                guard let device = notification.object as? AVCaptureDevice else { return }
                guard device.uniqueID == self.settings.cameraID else { return }
                self.cameraStore.refresh()
                self.syncCameraSelection()
            }
        )

        cameraStore.$devices
            .sink { [weak self] _ in
                self?.syncCameraSelection()
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

        requestCameraAccessIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.shouldResumeMonitoringOnLaunch else { return }
            self.startMonitoring()
        }
    }

    deinit {
        deviceObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func syncCameraSelection() {
        let devices = cameraStore.devices
        let storedID = settings.cameraID

        if devices.isEmpty {
            if storedID != nil {
                settings.cameraID = nil
            }
            if isMonitoring || isStarting {
                resumeMonitoringWhenCameraAvailable = true
                stopMonitoring()
            }
            return
        }

        let preferred = cameraStore.preferredDeviceID(storedID: storedID)
        if preferred != storedID {
            settings.cameraID = preferred
        }

        if resumeMonitoringWhenCameraAvailable {
            resumeMonitoringWhenCameraAvailable = false
            if !isMonitoring && !isStarting {
                startMonitoring()
            }
        }
    }

    private func requestCameraAccessIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .video) { _ in }
    }

    func toggleMonitoring() {
        if isMonitoring || isStarting {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        guard !isMonitoring, !isStarting else { return }
        cameraStore.refresh()
        let availableDevices = cameraStore.devices
        if settings.cameraID == nil || availableDevices.contains(where: { $0.uniqueID == settings.cameraID }) == false {
            settings.cameraID = cameraStore.preferredDeviceID(storedID: settings.cameraID)
        }
        lastError = nil
        isStarting = true
        isAwaitingCamera = true
        lastFrameTime = 0
        startFrameStallMonitor()
        detectionEngine.start { [weak self] error in
            guard let self else { return }
            self.isStarting = false
            if let error {
                self.isMonitoring = false
                self.isAwaitingCamera = false
                self.stopFrameStallMonitor()
                self.lastError = error
                return
            }

            self.isMonitoring = true
            self.resetTouchState()
            self.stateDefaults.set(true, forKey: Self.resumeMonitoringKey)
            self.stats.beginMonitoring()
            self.beginMonitoringActivity()
            if self.settings.alertSoundEnabled {
                self.alertManager.prepareContinuous()
            }
        }
    }

    func stopMonitoring() {
        isStarting = false
        isAwaitingCamera = false
        stopFrameStallMonitor()
        detectionEngine.stop()
        stats.endMonitoring()
        endMonitoringActivity()
        blurOverlay.hide()
        clearSnooze()
        alertManager.shutdownContinuous()
        stateDefaults.set(false, forKey: Self.resumeMonitoringKey)
        resetTouchState()
        isMonitoring = false
        previewHandPoints = []
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    func setPreviewEnabled(_ enabled: Bool) {
        detectionEngine.setPreviewEnabled(enabled)
        if !enabled {
            previewImage = nil
            previewHandPoints = []
        }
    }

    private func startFrameStallMonitor() {
        stopFrameStallMonitor()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isMonitoring || self.isStarting else { return }
            let now = CACurrentMediaTime()
            if self.lastFrameTime == 0 {
                if self.isMonitoring && !self.isAwaitingCamera {
                    self.isAwaitingCamera = true
                }
                return
            }
            if now - self.lastFrameTime > self.frameStallThreshold {
                if !self.isAwaitingCamera {
                    self.isAwaitingCamera = true
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        frameStallTimer = timer
    }

    private func stopFrameStallMonitor() {
        frameStallTimer?.invalidate()
        frameStallTimer = nil
        lastFrameTime = 0
    }

    private func updateBlurOverlay(isHit: Bool) {
        guard isMonitoring, settings.flashScreenOnTouch else {
            blurOverlay.hide()
            return
        }
        guard !isSnoozed else {
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
        guard !isSnoozed else {
            resetTouchState()
            return
        }
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
        guard settings.alertSoundEnabled, !isSnoozed else {
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

    func snooze(for duration: TimeInterval) {
        let until = Date().addingTimeInterval(duration)
        setSnoozed(until: until)
        blurOverlay.hide()
        alertManager.stopContinuous()
        resetTouchState()
    }

    func resumeFromSnooze() {
        clearSnooze()
    }

    private func setSnoozed(until: Date) {
        snoozeTimer?.invalidate()
        snoozedUntil = until

        let timer = Timer(fireAt: until, interval: 0, target: self, selector: #selector(endSnoozeTimer), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        snoozeTimer = timer
    }

    private func clearSnooze() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        snoozedUntil = nil
    }

    @objc private func endSnoozeTimer() {
        clearSnooze()
    }

    private var shouldResumeMonitoringOnLaunch: Bool {
        stateDefaults.bool(forKey: Self.resumeMonitoringKey)
    }

    private func migrateResumeMonitoringStateIfNeeded() {
        guard stateDefaults.object(forKey: Self.resumeMonitoringKey) == nil else { return }
        guard stateDefaults.object(forKey: Self.legacyResumeMonitoringKey) != nil else { return }
        let legacyValue = stateDefaults.bool(forKey: Self.legacyResumeMonitoringKey)
        stateDefaults.set(legacyValue, forKey: Self.resumeMonitoringKey)
        stateDefaults.removeObject(forKey: Self.legacyResumeMonitoringKey)
    }

    private static let resumeMonitoringKey = "state.resumeMonitoringOnLaunch"
    private static let legacyResumeMonitoringKey = "settings.resumeMonitoringOnLaunch"

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

    private func handleTrigger() {
        guard !isSnoozed else { return }
        guard settings.alertBannerEnabled else { return }
        alertManager.postBanner()
    }
}
