#if DEBUG
import AVFoundation
import Combine
import CoreGraphics
import Foundation
import QuartzCore

struct UITestConfig {
    enum StartError: String {
        case permissionDenied
        case noCamera
        case configurationFailed
        case none
    }

    let startError: DetectionStartError?
    let emitPreview: Bool
    let emitFrame: Bool
    let emitHit: Bool
    let startDelay: TimeInterval
    let devices: [CameraDeviceInfo]
    let powerState: PowerState

    static func fromEnvironment(_ environment: [String: String]) -> UITestConfig {
        let errorValue = StartError(rawValue: environment["UITEST_START_ERROR"] ?? "none") ?? .none
        let startError: DetectionStartError?
        switch errorValue {
        case .permissionDenied:
            startError = .permissionDenied
        case .noCamera:
            startError = .noCamera
        case .configurationFailed:
            startError = .configurationFailed
        case .none:
            startError = nil
        }

        let emitPreview = environment["UITEST_PREVIEW"] != "0"
        let emitFrame = environment["UITEST_EMIT_FRAME"] != "0"
        let emitHit = environment["UITEST_HIT"] == "1"
        let startDelay = TimeInterval(environment["UITEST_START_DELAY"] ?? "") ?? 0
        let powerStateSetting = (environment["UITEST_POWER_STATE"] ?? "ac").lowercased()
        let powerState: PowerState
        switch powerStateSetting {
        case "battery":
            powerState = .onBattery
        case "low", "low_power", "lowpower":
            powerState = .lowPower
        default:
            powerState = .pluggedIn
        }

        let devicesSetting = environment["UITEST_CAMERA_DEVICES"] ?? "default"
        let devices: [CameraDeviceInfo]
        switch devicesSetting {
        case "none":
            devices = []
        case "external":
            devices = [CameraDeviceInfo(id: "extCam", name: "External Camera", isExternal: true)]
        default:
            devices = [CameraDeviceInfo(id: "builtIn", name: "Built-in Camera", isExternal: false)]
        }

        return UITestConfig(
            startError: startError,
            emitPreview: emitPreview,
            emitFrame: emitFrame,
            emitHit: emitHit,
            startDelay: startDelay,
            devices: devices,
            powerState: powerState
        )
    }
}

final class UITestDetectionEngine: DetectionEngineType {
    private let config: UITestConfig
    private let onTrigger: () -> Void
    private var observationHandler: ((DetectionObservation) -> Void)?
    private var previewHandler: ((CGImage) -> Void)?
    private var frameHandler: (() -> Void)?
    private var previewEnabled = false
    private var didEmitPreview = false
    private var didEmitObservation = false
    private var isRunning = false
    private var hasCompletedStart = false
    private var pendingStartWork: DispatchWorkItem?

    init(config: UITestConfig, onTrigger: @escaping () -> Void) {
        self.config = config
        self.onTrigger = onTrigger
    }

    func start(completion: @escaping (DetectionStartError?) -> Void) {
        if let startError = config.startError {
            DispatchQueue.main.async {
                completion(startError)
            }
            return
        }
        didEmitPreview = false
        didEmitObservation = false
        hasCompletedStart = false
        isRunning = true
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.hasCompletedStart = true
            completion(nil)
            if self.config.emitFrame {
                self.frameHandler?()
            }
            self.emitPreviewIfNeeded()
            self.emitObservationIfNeeded()
            self.pendingStartWork = nil
        }
        pendingStartWork = work
        if config.startDelay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.startDelay, execute: work)
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    func stop() {
        isRunning = false
        pendingStartWork?.cancel()
        pendingStartWork = nil
    }

    func setObservationHandler(_ handler: @escaping (DetectionObservation) -> Void) {
        observationHandler = handler
    }

    func setPreviewHandler(_ handler: @escaping (CGImage) -> Void) {
        previewHandler = handler
    }

    func setFrameHandler(_ handler: @escaping () -> Void) {
        frameHandler = handler
    }

    func setPreviewEnabled(_ enabled: Bool) {
        previewEnabled = enabled
        emitPreviewIfNeeded()
    }

    func setFrameInterval(_ interval: CFTimeInterval) {
        // No-op for UI tests.
    }

    private func emitPreviewIfNeeded() {
        guard isRunning, hasCompletedStart, previewEnabled, config.emitPreview, !didEmitPreview else { return }
        guard let image = makePreviewImage() else { return }
        didEmitPreview = true
        previewHandler?(image)
    }

    private func emitObservationIfNeeded() {
        guard isRunning, hasCompletedStart, !didEmitObservation else { return }
        didEmitObservation = true
        let faceZone: CGRect? = config.emitHit
            ? CGRect(x: 0.3, y: 0.3, width: 0.2, height: 0.25)
            : nil
        let handPoints: [CGPoint] = config.emitHit
            ? [CGPoint(x: 0.35, y: 0.35), CGPoint(x: 0.6, y: 0.55)]
            : []
        observationHandler?(DetectionObservation(hit: config.emitHit, faceZone: faceZone, handPoints: handPoints))
        if config.emitHit {
            onTrigger()
        }
    }

    private func makePreviewImage() -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage()
    }
}

final class UITestCameraStore: ObservableObject, CameraStoreType {
    @Published private(set) var devices: [CameraDeviceInfo]

    init(devices: [CameraDeviceInfo]) {
        self.devices = devices
    }

    var devicesPublisher: Published<[CameraDeviceInfo]>.Publisher { $devices }

    func refresh() {
        // No-op for UI tests.
    }

    func preferredDeviceID(storedID: String?) -> String? {
        CameraStore.preferredDeviceID(storedID: storedID, devices: devices)
    }
}

final class NoopAlertManager: AlertManaging {
    func ensureNotificationAuthorization() {}
    func startContinuous() {}
    func stopContinuous() {}
    func prepareContinuous() {}
    func shutdownContinuous() {}
    func postBanner() {}
}

final class NoopBlurOverlay: BlurOverlaying {
    func show() {}
    func hide() {}
}

final class NoopLoginItemManager: LoginItemManaging {
    var isSupported: Bool { false }
    func isEnabled() -> Bool { false }
    func setEnabled(_ enabled: Bool) -> Bool { true }
}

extension AppStateDependencies {
    static func uiTest() -> AppStateDependencies {
        let environment = ProcessInfo.processInfo.environment
        let config = UITestConfig.fromEnvironment(environment)
        let suiteName = "HandsOff.UITests"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let settings = SettingsStore(defaults: defaults)
        settings.cameraID = config.devices.first?.id

        let stats = StatsStore(defaults: defaults)
        let cameraStore = UITestCameraStore(devices: config.devices)
        let alertManager = NoopAlertManager()
        let blurOverlay = NoopBlurOverlay()
        let loginItemManager = NoopLoginItemManager()

        return AppStateDependencies(
            settings: settings,
            stats: stats,
            cameraStore: cameraStore,
            alertManager: alertManager,
            blurOverlay: blurOverlay,
            loginItemManager: loginItemManager,
            detectionEngineFactory: { _, onTrigger in
                UITestDetectionEngine(config: config, onTrigger: onTrigger)
            },
            userDefaults: defaults,
            notificationCenter: .default,
            workspaceNotificationCenter: .default,
            powerStateMonitor: StaticPowerStateMonitor(state: config.powerState),
            timerDriver: .live,
            now: Date.init,
            mediaTime: CACurrentMediaTime,
            cameraAuthorizationStatus: { .authorized },
            requestCameraAccess: { completion in
                completion(true)
            },
            openCameraSettings: {},
            terminateApp: {},
            activityController: ActivityController(begin: { _ in NSObject() }, end: { _ in }),
            cameraStallAlertPresenter: { _, _, _, _, _ in }
        )
    }
}
#endif
