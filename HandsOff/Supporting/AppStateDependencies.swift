import AppKit
import AVFoundation
import Foundation

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
    var timerDriver: TimerDriver
    var now: () -> Date
    var mediaTime: () -> CFTimeInterval
    var cameraAuthorizationStatus: () -> AVAuthorizationStatus
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
            timerDriver: .live,
            now: Date.init,
            mediaTime: CACurrentMediaTime,
            cameraAuthorizationStatus: { AVCaptureDevice.authorizationStatus(for: .video) },
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
            if let newSelectedID = cameraPicker.selectedItem?.representedObject as? String,
               newSelectedID != (selectedID ?? "") {
                onSelect(newSelectedID)
            }
                if response == .alertFirstButtonReturn {
                    onRetry()
                }
            }
        )
    }
}
