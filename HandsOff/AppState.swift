import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Foundation

final class AppState: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published private(set) var isStarting = false
    @Published private(set) var isAwaitingCamera = false
    @Published private(set) var isCameraStalled = false
    @Published var lastError: DetectionStartError?
    @Published var previewHit = false
    @Published var previewFaceZone: CGRect?
    @Published var previewImage: CGImage?
    @Published var previewHandPoints: [CGPoint] = []
    @Published private(set) var snoozedUntil: Date?

    let settings: SettingsStore
    let stats: StatsStore
    let cameraStore: AnyCameraStore

    private let alertManager: AlertManaging
    private let blurOverlay: BlurOverlaying
    private let loginItemManager: LoginItemManaging
    private let stateDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let timerDriver: TimerDriver
    private let now: () -> Date
    private let mediaTime: () -> CFTimeInterval
    private let openCameraSettingsHandler: () -> Void
    private let terminateAppHandler: () -> Void
    private let activityController: ActivityController
    private let cameraStallAlertPresenter: CameraStallAlertPresenter
    private let detectionEngineFactory: DetectionEngineFactory
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
    private var awaitingCameraSince: CFTimeInterval?
    private let cameraStartTimeout: CFTimeInterval = 6.0
    private var cameraStallAlertShown = false
    private var isSoundPlaying = false
    private var startRequestID: UUID?
    private static let isTesting = {
        let environment = ProcessInfo.processInfo.environment
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING") { return true }
        if environment["UITEST"] == "1" { return true }
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["XCTestSessionIdentifier"] != nil { return true }
        return NSClassFromString("XCTest") != nil
    }()
        || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    private lazy var detectionEngine: DetectionEngineType = detectionEngineFactory(
        { [weak self] in
            guard let self else {
                return DetectionSettings(cameraID: nil, faceZoneScale: CGFloat(SettingsStore.faceZoneBaselineScale))
            }
            return DetectionSettings(
                cameraID: self.settings.cameraID,
                faceZoneScale: CGFloat(self.settings.faceZoneScale * SettingsStore.faceZoneBaselineScale)
            )
        },
        { [weak self] in
            self?.handleTrigger()
        }
    )

    var isSnoozed: Bool {
        guard let snoozedUntil else { return false }
        return snoozedUntil > now()
    }

    init(dependencies: AppStateDependencies = .live()) {
        self.settings = dependencies.settings
        self.stats = dependencies.stats
        self.cameraStore = AnyCameraStore(dependencies.cameraStore)
        self.alertManager = dependencies.alertManager
        self.blurOverlay = dependencies.blurOverlay
        self.loginItemManager = dependencies.loginItemManager
        self.stateDefaults = dependencies.userDefaults
        self.notificationCenter = dependencies.notificationCenter
        self.timerDriver = dependencies.timerDriver
        self.now = dependencies.now
        self.mediaTime = dependencies.mediaTime
        self.openCameraSettingsHandler = dependencies.openCameraSettings
        self.terminateAppHandler = dependencies.terminateApp
        self.activityController = dependencies.activityController
        self.cameraStallAlertPresenter = dependencies.cameraStallAlertPresenter
        self.detectionEngineFactory = dependencies.detectionEngineFactory
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
            let currentTime = self.mediaTime()
            self.lastFrameTime = currentTime
            if self.isAwaitingCamera {
                self.setAwaitingCamera(false)
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
                    self.isSoundPlaying = false
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
            .dropFirst()
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
            notificationCenter.addObserver(
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

        cameraStore.devicesPublisher
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

        if !Self.isTesting {
            requestCameraAccessIfNeeded()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !Self.isTesting else { return }
            guard self.shouldResumeMonitoringOnLaunch else { return }
            self.startMonitoring()
        }
    }

    deinit {
        deviceObservers.forEach { notificationCenter.removeObserver($0) }
    }

    private func syncCameraSelection() {
        let devices = cameraStore.devices
        let storedID = settings.cameraID

        if devices.isEmpty {
            if isMonitoring || isStarting {
                resumeMonitoringWhenCameraAvailable = true
                stopMonitoring()
            }
            if storedID != nil {
                settings.cameraID = nil
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
        let requestID = UUID()
        startRequestID = requestID
        cameraStore.refresh()
        let availableDevices = cameraStore.devices
        if settings.cameraID == nil || availableDevices.contains(where: { $0.id == settings.cameraID }) == false {
            settings.cameraID = cameraStore.preferredDeviceID(storedID: settings.cameraID)
        }
        lastError = nil
        previewImage = nil
        previewFaceZone = nil
        previewHit = false
        previewHandPoints = []
        isStarting = true
        setAwaitingCamera(true)
        lastFrameTime = 0
        startFrameStallMonitor()
        detectionEngine.start { [weak self] error in
            guard let self else { return }
            guard self.startRequestID == requestID, self.isStarting else { return }
            self.startRequestID = nil
            self.isStarting = false
            if let error {
                self.isMonitoring = false
                self.setAwaitingCamera(false)
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
        startRequestID = nil
        isStarting = false
        setAwaitingCamera(false)
        stopFrameStallMonitor()
        detectionEngine.stop()
        stats.endMonitoring()
        endMonitoringActivity()
        blurOverlay.hide()
        clearSnooze()
        alertManager.shutdownContinuous()
        isSoundPlaying = false
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
        let timer = timerDriver.makeRepeating(0.5) { [weak self] in
            guard let self else { return }
            guard self.isMonitoring || self.isStarting else { return }
            let now = self.mediaTime()
            if self.lastFrameTime == 0 {
                self.setAwaitingCamera(true)
                self.evaluateCameraStall(now: now)
                return
            }
            if now - self.lastFrameTime > self.frameStallThreshold {
                self.setAwaitingCamera(true)
                self.evaluateCameraStall(now: now)
            }
        }
        timerDriver.schedule(timer)
        frameStallTimer = timer
    }

    private func stopFrameStallMonitor() {
        frameStallTimer?.invalidate()
        frameStallTimer = nil
        lastFrameTime = 0
    }

    private func setAwaitingCamera(_ awaiting: Bool) {
        if awaiting {
            if isAwaitingCamera {
                if awaitingCameraSince == nil {
                    awaitingCameraSince = mediaTime()
                }
                return
            }
            previewImage = nil
            previewFaceZone = nil
            previewHit = false
            previewHandPoints = []
            awaitingCameraSince = mediaTime()
            isAwaitingCamera = true
            return
        }
        if !isAwaitingCamera && !cameraStallAlertShown && !isCameraStalled {
            return
        }
        awaitingCameraSince = nil
        cameraStallAlertShown = false
        isCameraStalled = false
        isAwaitingCamera = false
    }

    private func evaluateCameraStall(now: CFTimeInterval) {
        guard !cameraStallAlertShown else { return }
        guard let awaitingCameraSince else { return }
        guard now - awaitingCameraSince >= cameraStartTimeout else { return }
        cameraStallAlertShown = true
        isCameraStalled = true
        presentCameraStallAlert()
    }

    private func presentCameraStallAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cameraStore.refresh()
            let devices = self.cameraStore.devices
            let cameraName = self.currentCameraName()
            self.cameraStallAlertPresenter(
                devices,
                cameraName,
                self.settings.cameraID,
                { [weak self] in
                    self?.restartMonitoring()
                },
                { [weak self] selectedID in
                    self?.settings.cameraID = selectedID
                }
            )
        }
    }

    private func currentCameraName() -> String {
        guard let cameraID = settings.cameraID else {
            return "the selected camera"
        }
        if let match = cameraStore.devices.first(where: { $0.id == cameraID }) {
            return match.name
        }
        return "the selected camera"
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
        let now = mediaTime()
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
            if isSoundPlaying {
                alertManager.stopContinuous()
                isSoundPlaying = false
            }
            return
        }
        if isHit {
            if !isSoundPlaying {
                alertManager.startContinuous()
                isSoundPlaying = true
            }
        } else if isSoundPlaying {
            alertManager.stopContinuous()
            isSoundPlaying = false
        }
    }

    private func resetTouchState() {
        isTouching = false
        touchReleaseStart = nil
    }

    func snooze(for duration: TimeInterval) {
        let until = now().addingTimeInterval(duration)
        setSnoozed(until: until)
        blurOverlay.hide()
        alertManager.stopContinuous()
        isSoundPlaying = false
        resetTouchState()
    }

    func resumeFromSnooze() {
        clearSnooze()
    }

    private func setSnoozed(until: Date) {
        snoozeTimer?.invalidate()
        snoozedUntil = until

        let timer = timerDriver.makeOneShot(until) { [weak self] in
            self?.clearSnooze()
        }
        timerDriver.schedule(timer)
        snoozeTimer = timer
    }

    private func clearSnooze() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        snoozedUntil = nil
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
        openCameraSettingsHandler()
    }

    func terminateApp() {
        terminateAppHandler()
    }

    private func beginMonitoringActivity() {
        guard monitoringActivity == nil else { return }
        monitoringActivity = activityController.begin("HandsOff monitoring")
    }

    private func endMonitoringActivity() {
        guard let monitoringActivity else { return }
        activityController.end(monitoringActivity)
        self.monitoringActivity = nil
    }

    private func handleTrigger() {
        guard !isSnoozed else { return }
        guard settings.alertBannerEnabled else { return }
        alertManager.postBanner()
    }
}

#if DEBUG
extension AppState {
    func _testEvaluateCameraStall(now: CFTimeInterval) {
        evaluateCameraStall(now: now)
    }

    func _testSetAwaitingCamera(_ awaiting: Bool) {
        setAwaitingCamera(awaiting)
    }

    func _testSyncCameraSelection() {
        syncCameraSelection()
    }

    func _testHandleTrigger() {
        handleTrigger()
    }

    var _testIsTouching: Bool {
        isTouching
    }
}
#endif
