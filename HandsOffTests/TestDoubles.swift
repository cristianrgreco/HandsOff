import Combine
import CoreGraphics
import Foundation
@testable import HandsOff

final class TestAlertManager: AlertManaging {
    private(set) var ensureAuthorizationCount = 0
    private(set) var startContinuousCount = 0
    private(set) var stopContinuousCount = 0
    private(set) var prepareContinuousCount = 0
    private(set) var shutdownContinuousCount = 0
    private(set) var postBannerCount = 0

    func ensureNotificationAuthorization() {
        ensureAuthorizationCount += 1
    }

    func startContinuous() {
        startContinuousCount += 1
    }

    func stopContinuous() {
        stopContinuousCount += 1
    }

    func prepareContinuous() {
        prepareContinuousCount += 1
    }

    func shutdownContinuous() {
        shutdownContinuousCount += 1
    }

    func postBanner() {
        postBannerCount += 1
    }
}

final class TestBlurOverlay: BlurOverlaying {
    private(set) var showCount = 0
    private(set) var hideCount = 0

    func show() {
        showCount += 1
    }

    func hide() {
        hideCount += 1
    }
}

final class TestLoginItemManager: LoginItemManaging {
    var isSupported: Bool = true
    private(set) var enabled = false
    private(set) var setEnabledValues: [Bool] = []

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        setEnabledValues.append(enabled)
        self.enabled = enabled
        return true
    }
}

final class TestDetectionEngine: DetectionEngineType {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var previewEnabledValues: [Bool] = []
    private(set) var frameIntervalValues: [CFTimeInterval] = []
    private var startCompletion: ((DetectionStartError?) -> Void)?
    private var observationHandler: ((DetectionObservation) -> Void)?
    private var previewHandler: ((CGImage) -> Void)?
    private var frameHandler: (() -> Void)?
    var triggerHandler: (() -> Void)?

    func start(completion: @escaping (DetectionStartError?) -> Void) {
        startCount += 1
        startCompletion = completion
    }

    func stop() {
        stopCount += 1
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
        previewEnabledValues.append(enabled)
    }

    func setFrameInterval(_ interval: CFTimeInterval) {
        frameIntervalValues.append(interval)
    }

    func completeStart(with error: DetectionStartError?) {
        startCompletion?(error)
    }

    func emitObservation(hit: Bool, faceZone: CGRect? = nil, handPoints: [CGPoint] = []) {
        observationHandler?(DetectionObservation(hit: hit, faceZone: faceZone, handPoints: handPoints))
    }

    func emitFrame() {
        frameHandler?()
    }

    func emitPreview(image: CGImage) {
        previewHandler?(image)
    }

    func emitTrigger() {
        triggerHandler?()
    }
}

final class TestPowerStateMonitor: PowerStateObserving {
    private let subject: CurrentValueSubject<PowerState, Never>

    init(state: PowerState) {
        self.subject = CurrentValueSubject(state)
    }

    var currentState: PowerState {
        subject.value
    }

    var statePublisher: AnyPublisher<PowerState, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ state: PowerState) {
        subject.send(state)
    }
}

final class TestCameraStore: CameraStoreType {
    @Published var devices: [CameraDeviceInfo]
    private(set) var refreshCount = 0

    init(devices: [CameraDeviceInfo] = []) {
        self.devices = devices
    }

    var devicesPublisher: Published<[CameraDeviceInfo]>.Publisher { $devices }

    func refresh() {
        refreshCount += 1
    }

    func preferredDeviceID(storedID: String?) -> String? {
        CameraStore.preferredDeviceID(storedID: storedID, devices: devices)
    }
}

final class TestTimerDriver {
    private(set) var scheduled: [Timer] = []
    private(set) var makeRepeatingCount = 0
    private(set) var makeOneShotCount = 0

    func makeDriver() -> TimerDriver {
        TimerDriver(
            makeRepeating: { [weak self] interval, handler in
                self?.makeRepeatingCount += 1
                let timer = Timer(timeInterval: interval, repeats: true) { _ in
                    handler()
                }
                return timer
            },
            makeOneShot: { [weak self] date, handler in
                self?.makeOneShotCount += 1
                let timer = Timer(fire: date, interval: 0, repeats: false) { _ in
                    handler()
                }
                return timer
            },
            schedule: { [weak self] timer in
                self?.scheduled.append(timer)
            }
        )
    }
}

struct TestClock {
    var now: Date
    var mediaTime: CFTimeInterval
}
