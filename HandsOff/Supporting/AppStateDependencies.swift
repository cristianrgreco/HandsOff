import AppKit
import AVFoundation
import Combine
import Foundation
import IOKit.ps

protocol AlertManaging: AnyObject {
    func ensureNotificationAuthorization()
    func startContinuous()
    func stopContinuous()
    func prepareContinuous()
    func shutdownContinuous()
    func postBanner()
}

protocol BlurOverlaying: AnyObject {
    func show()
    func hide()
}

protocol LoginItemManaging: AnyObject {
    var isSupported: Bool { get }
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) -> Bool
}

protocol DetectionEngineType: AnyObject {
    func start(completion: @escaping (DetectionStartError?) -> Void)
    func stop()
    func setObservationHandler(_ handler: @escaping (DetectionObservation) -> Void)
    func setPreviewHandler(_ handler: @escaping (CGImage) -> Void)
    func setFrameHandler(_ handler: @escaping () -> Void)
    func setPreviewEnabled(_ enabled: Bool)
    func setFrameInterval(_ interval: CFTimeInterval)
}

extension AlertManager: AlertManaging {}
extension BlurOverlayController: BlurOverlaying {}
extension LoginItemManager: LoginItemManaging {}
extension DetectionEngine: DetectionEngineType {}

typealias DetectionEngineFactory = (_ settingsProvider: @escaping () -> DetectionSettings, _ onTrigger: @escaping () -> Void) -> DetectionEngineType
typealias CameraStallAlertPresenter = (_ devices: [CameraDeviceInfo], _ cameraName: String, _ selectedID: String?, _ onRetry: @escaping () -> Void, _ onSelect: @escaping (String) -> Void) -> Void

struct ActivityController {
    let begin: (String) -> NSObjectProtocol
    let end: (NSObjectProtocol) -> Void

    static let live = ActivityController(
        begin: { reason in
            ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: reason
            )
        },
        end: { token in
            ProcessInfo.processInfo.endActivity(token)
        }
    )
}

struct TimerDriver {
    let makeRepeating: (TimeInterval, @escaping () -> Void) -> Timer
    let makeOneShot: (Date, @escaping () -> Void) -> Timer
    let schedule: (Timer) -> Void

    static let live = TimerDriver(
        makeRepeating: { interval, handler in
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                handler()
            }
        },
        makeOneShot: { date, handler in
            Timer(fire: date, interval: 0, repeats: false) { _ in
                handler()
            }
        },
        schedule: { timer in
            RunLoop.main.add(timer, forMode: .common)
        }
    )
}

struct AppStateDependencies {
    var settings: SettingsStore
    var stats: StatsStore
    var cameraStore: any CameraStoreType
    var alertManager: AlertManaging
    var blurOverlay: BlurOverlaying
    var loginItemManager: LoginItemManaging
    var detectionEngineFactory: DetectionEngineFactory
    var userDefaults: UserDefaults
    var notificationCenter: NotificationCenter
    var workspaceNotificationCenter: NotificationCenter
    var distributedNotificationCenter: NotificationCenter
    var powerStateMonitor: PowerStateObserving
    var timerDriver: TimerDriver
    var now: () -> Date
    var mediaTime: () -> CFTimeInterval
    var cameraAuthorizationStatus: () -> AVAuthorizationStatus
    var requestCameraAccess: (@escaping (Bool) -> Void) -> Void
    var openCameraSettings: () -> Void
    var terminateApp: () -> Void
    var activityController: ActivityController
    var cameraStallAlertPresenter: CameraStallAlertPresenter

    static func live() -> AppStateDependencies {
        let settings = SettingsStore()
        let stats = StatsStore()
        let cameraStore = CameraStore()
        let alertManager = AlertManager()
        let blurOverlay = BlurOverlayController()
        let loginItemManager = LoginItemManager()

        return AppStateDependencies(
            settings: settings,
            stats: stats,
            cameraStore: cameraStore,
            alertManager: alertManager,
            blurOverlay: blurOverlay,
            loginItemManager: loginItemManager,
            detectionEngineFactory: { settingsProvider, onTrigger in
                DetectionEngine(settingsProvider: settingsProvider, onTrigger: onTrigger)
            },
            userDefaults: .standard,
            notificationCenter: .default,
            workspaceNotificationCenter: NSWorkspace.shared.notificationCenter,
            distributedNotificationCenter: DistributedNotificationCenter.default(),
            powerStateMonitor: PowerStateMonitor(),
            timerDriver: .live,
            now: Date.init,
            mediaTime: CACurrentMediaTime,
            cameraAuthorizationStatus: { AVCaptureDevice.authorizationStatus(for: .video) },
            requestCameraAccess: { completion in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    completion(granted)
                }
            },
            openCameraSettings: {
                guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
                    return
                }
                NSWorkspace.shared.open(url)
            },
            terminateApp: {
                NSApplication.shared.terminate(nil)
            },
            activityController: .live,
            cameraStallAlertPresenter: { devices, cameraName, selectedID, onRetry, onSelect in
                let alert = NSAlert()
                alert.messageText = "Camera isn't responding"
                alert.informativeText = "Hands Off isn't getting frames from “\(cameraName)”. Select a different camera below, or try again."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Try Again")
                alert.addButton(withTitle: "Dismiss")
                let cameraPicker = NSPopUpButton(
                    frame: NSRect(x: 0, y: 0, width: 280, height: 26),
                    pullsDown: false
                )
                if devices.isEmpty {
                    cameraPicker.addItem(withTitle: "No cameras detected")
                    cameraPicker.isEnabled = false
                } else {
                    for device in devices {
                        let item = NSMenuItem(title: device.name, action: nil, keyEquivalent: "")
                        item.representedObject = device.id
                        cameraPicker.menu?.addItem(item)
                    }
                if let currentSelectedID = selectedID,
                   let index = devices.firstIndex(where: { $0.id == currentSelectedID }) {
                    cameraPicker.selectItem(at: index)
                }
            }
                alert.accessoryView = cameraPicker
                NSApp.activate(ignoringOtherApps: true)
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let newSelectedID = cameraPicker.selectedItem?.representedObject as? String,
                       newSelectedID != (selectedID ?? "") {
                        onSelect(newSelectedID)
                    }
                    onRetry()
                }
            }
        )
    }
}

enum PowerState: Equatable {
    case pluggedIn
    case onBattery
    case lowPower
}

protocol PowerStateObserving {
    var currentState: PowerState { get }
    var statePublisher: AnyPublisher<PowerState, Never> { get }
}

final class PowerStateMonitor: PowerStateObserving {
    private let notificationCenter: NotificationCenter
    private let subject: CurrentValueSubject<PowerState, Never>
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var powerStateObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        self.subject = CurrentValueSubject(Self.resolveState())
        start()
    }

    deinit {
        stop()
    }

    var currentState: PowerState {
        subject.value
    }

    var statePublisher: AnyPublisher<PowerState, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func start() {
        if powerStateObserver == nil {
            powerStateObserver = notificationCenter.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateState()
            }
        }

        if powerSourceRunLoopSource == nil {
            let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            guard let source = IOPSNotificationCreateRunLoopSource(powerSourceCallback, context)?
                .takeRetainedValue()
            else {
                return
            }
            powerSourceRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }

        updateState()
    }

    private func stop() {
        if let powerStateObserver {
            notificationCenter.removeObserver(powerStateObserver)
            self.powerStateObserver = nil
        }
        if let powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .defaultMode)
            self.powerSourceRunLoopSource = nil
        }
    }

    fileprivate func updateState() {
        let state = Self.resolveState()
        if state != subject.value {
            subject.send(state)
        }
    }

    private static func resolveState() -> PowerState {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return .lowPower
        }
        return isOnBattery() ? .onBattery : .pluggedIn
    }

    private static func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                  let powerState = description[kIOPSPowerSourceStateKey] as? String
            else {
                continue
            }
            if powerState == kIOPSBatteryPowerValue {
                return true
            }
        }

        return false
    }
}

final class StaticPowerStateMonitor: PowerStateObserving {
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

    func update(_ state: PowerState) {
        subject.send(state)
    }
}

private func powerSourceCallback(context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let monitor = Unmanaged<PowerStateMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.updateState()
}
