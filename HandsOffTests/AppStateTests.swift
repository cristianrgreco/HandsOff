import AppKit
import AVFoundation
import CoreGraphics
import XCTest
@testable import HandsOff

final class AppStateTests: XCTestCase {
    func testStartMonitoringSuccessSetsFlagsAndBeginsMonitoring() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        XCTAssertTrue(appState.isStarting)
        XCTAssertTrue(appState.isAwaitingCamera)
        XCTAssertEqual(harness.cameraStore.refreshCount, 1)
        XCTAssertEqual(harness.timerDriver.makeRepeatingCount, 1)

        harness.detectionEngine.completeStart(with: nil)

        XCTAssertTrue(appState.isMonitoring)
        XCTAssertFalse(appState.isStarting)
        XCTAssertNotNil(harness.stats._testMonitoringStart)
        XCTAssertEqual(harness.alertManager.prepareContinuousCount, 1)
        XCTAssertEqual(harness.activityCapture.beginCount, 1)
        XCTAssertTrue(harness.defaults.bool(forKey: "state.resumeMonitoringOnLaunch"))
    }

    func testStartMonitoringClearsPreviewState() {
        let harness = makeHarness()
        let appState = harness.appState
        appState.previewImage = makeImage()
        appState.previewHandPoints = [CGPoint(x: 0.1, y: 0.2)]
        appState.previewFaceZone = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        appState.previewHit = true

        appState.startMonitoring()

        XCTAssertNil(appState.previewImage)
        XCTAssertTrue(appState.previewHandPoints.isEmpty)
        XCTAssertNil(appState.previewFaceZone)
        XCTAssertFalse(appState.previewHit)
    }

    func testStartMonitoringFailureSetsError() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: .permissionDenied)

        XCTAssertFalse(appState.isMonitoring)
        XCTAssertFalse(appState.isStarting)
        XCTAssertEqual(appState.lastError, .permissionDenied)
    }

    func testPermissionDeniedShowsCameraSettingsAction() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: .permissionDenied)

        XCTAssertEqual(appState.lastError, .permissionDenied)
        XCTAssertTrue(MenuBarStatus.shouldShowOpenCameraSettings(error: appState.lastError))
    }

    func testStartMonitoringNoCameraError() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: .noCamera)

        XCTAssertEqual(appState.lastError, .noCamera)
        XCTAssertFalse(appState.isMonitoring)
    }

    func testStopMonitoringEndsActivityAndClearsSnooze() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        appState.snooze(for: 60)

        appState.stopMonitoring()

        XCTAssertFalse(appState.isMonitoring)
        XCTAssertNil(appState.snoozedUntil)
        XCTAssertEqual(harness.alertManager.shutdownContinuousCount, 1)
        XCTAssertGreaterThanOrEqual(harness.blurOverlay.hideCount, 1)
        XCTAssertEqual(harness.detectionEngine.stopCount, 1)
        XCTAssertEqual(harness.activityCapture.endCount, 1)
        XCTAssertFalse(appState._testIsTouching)
        XCTAssertFalse(harness.defaults.bool(forKey: "state.resumeMonitoringOnLaunch"))
    }

    func testSnoozeUsesClockAndStopsAlerts() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.snooze(for: 120)

        XCTAssertEqual(appState.snoozedUntil, harness.clock.now.addingTimeInterval(120))
        XCTAssertEqual(harness.blurOverlay.hideCount, 1)
        XCTAssertEqual(harness.alertManager.stopContinuousCount, 1)
    }

    func testSnoozeResetsTouchState() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertTrue(appState._testIsTouching)

        appState.snooze(for: 30)

        XCTAssertFalse(appState._testIsTouching)
    }

    func testSnoozedDisablesAlertsWhileMonitoring() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        appState.snooze(for: 30)

        harness.detectionEngine.emitObservation(hit: true)

        XCTAssertEqual(harness.alertManager.startContinuousCount, 0)
        XCTAssertEqual(harness.blurOverlay.showCount, 0)
    }

    func testSnoozeEndsAndAlertsResume() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)

        appState.snooze(for: 60)
        XCTAssertTrue(appState.isSnoozed)
        XCTAssertEqual(harness.timerDriver.makeOneShotCount, 1)
        harness.timerDriver.scheduled.last?.fire()
        XCTAssertFalse(appState.isSnoozed)

        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertEqual(harness.alertManager.startContinuousCount, 1)
        XCTAssertEqual(harness.blurOverlay.showCount, 1)
    }

    func testIsSnoozedUsesInjectedClock() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.snooze(for: 60)
        XCTAssertTrue(appState.isSnoozed)

        harness.clock.now = harness.clock.now.addingTimeInterval(120)
        XCTAssertFalse(appState.isSnoozed)
    }

    func testBannerPostingRespectsSettings() {
        let harness = makeHarness(alertBannerEnabled: true)
        let appState = harness.appState

        appState._testHandleTrigger()
        XCTAssertEqual(harness.alertManager.postBannerCount, 1)

        harness.settings.alertBannerEnabled = false
        appState._testHandleTrigger()
        XCTAssertEqual(harness.alertManager.postBannerCount, 1)
    }

    func testBannerAuthorizationRequestedWhenEnabled() {
        let harness = makeHarness(alertBannerEnabled: false)

        harness.settings.alertBannerEnabled = true

        XCTAssertEqual(harness.alertManager.ensureAuthorizationCount, 1)
    }

    func testBannerToggleDoesNotRestartMonitoring() {
        let harness = makeHarness(alertBannerEnabled: false)
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        let startCount = harness.detectionEngine.startCount

        harness.settings.alertBannerEnabled = true

        XCTAssertEqual(harness.detectionEngine.startCount, startCount)
        XCTAssertEqual(harness.alertManager.ensureAuthorizationCount, 1)
    }

    func testPreviewEnableTogglesDetectionEngine() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.setPreviewEnabled(true)
        appState.setPreviewEnabled(false)

        XCTAssertEqual(harness.detectionEngine.previewEnabledValues, [true, false])
    }

    func testDisablingPreviewClearsPreviewState() {
        let harness = makeHarness()
        let appState = harness.appState
        appState.previewHandPoints = [CGPoint(x: 1, y: 1)]
        appState.previewImage = makeImage()

        appState.setPreviewEnabled(false)

        XCTAssertTrue(appState.previewHandPoints.isEmpty)
        XCTAssertNil(appState.previewImage)
    }

    func testPreviewHandlerUpdatesImage() {
        let harness = makeHarness()
        let appState = harness.appState
        guard let image = makeImage() else {
            XCTFail("Failed to create image")
            return
        }

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        harness.detectionEngine.emitPreview(image: image)

        XCTAssertNotNil(appState.previewImage)
    }

    func testFrameHandlerClearsAwaitingCamera() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        XCTAssertTrue(appState.isAwaitingCamera)

        harness.detectionEngine.emitFrame()

        XCTAssertFalse(appState.isAwaitingCamera)
    }

    func testContinuousToneLifecycle() {
        let harness = makeHarness(alertSoundEnabled: true)
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)

        harness.clock.mediaTime = 0
        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertEqual(harness.alertManager.startContinuousCount, 1)

        harness.clock.mediaTime = 0.1
        harness.detectionEngine.emitObservation(hit: false)
        XCTAssertEqual(harness.alertManager.stopContinuousCount, 1)

        harness.clock.mediaTime = 0.6
        harness.detectionEngine.emitObservation(hit: false)
        XCTAssertEqual(harness.alertManager.stopContinuousCount, 1)
    }

    func testDisableSoundStopsContinuous() {
        let harness = makeHarness(alertSoundEnabled: true)
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)

        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertEqual(harness.alertManager.startContinuousCount, 1)

        harness.settings.alertSoundEnabled = false
        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertEqual(harness.alertManager.shutdownContinuousCount, 1)
        XCTAssertEqual(harness.alertManager.startContinuousCount, 1)
    }

    func testDisableFlashHidesOverlay() {
        let harness = makeHarness(flashEnabled: true)
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)

        harness.detectionEngine.emitObservation(hit: true)
        XCTAssertEqual(harness.blurOverlay.showCount, 1)

        harness.settings.flashScreenOnTouch = false
        XCTAssertGreaterThanOrEqual(harness.blurOverlay.hideCount, 1)
    }

    func testEnablingSoundWhileMonitoringPreparesWithoutRestart() {
        let harness = makeHarness(alertSoundEnabled: false)
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        let startCount = harness.detectionEngine.startCount

        harness.settings.alertSoundEnabled = true

        XCTAssertEqual(harness.alertManager.prepareContinuousCount, 1)
        XCTAssertEqual(harness.detectionEngine.startCount, startCount)
    }

    func testCameraDisconnectStopsAndResumesMonitoring() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        XCTAssertTrue(appState.isMonitoring)

        harness.cameraStore.devices = []
        appState._testSyncCameraSelection()
        XCTAssertFalse(appState.isMonitoring)

        harness.cameraStore.devices = [CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false)]
        appState._testSyncCameraSelection()
        XCTAssertEqual(harness.detectionEngine.startCount, 2)
    }

    func testCameraSwitchWhileMonitoringRestartsOnce() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        XCTAssertEqual(harness.detectionEngine.startCount, 1)

        harness.settings.cameraID = "cam2"

        XCTAssertEqual(harness.detectionEngine.startCount, 1)
        harness.timerDriver.scheduled.last?.fire()

        XCTAssertEqual(harness.detectionEngine.startCount, 2)
    }

    func testCameraSwitchDebouncesRapidChanges() {
        let harness = makeHarness(cameraDevices: [
            CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false),
            CameraDeviceInfo(id: "cam2", name: "External", isExternal: true),
            CameraDeviceInfo(id: "cam3", name: "Virtual", isExternal: true)
        ])
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        XCTAssertEqual(harness.detectionEngine.startCount, 1)

        harness.settings.cameraID = "cam2"
        harness.settings.cameraID = "cam3"

        XCTAssertEqual(harness.detectionEngine.startCount, 1)
        harness.timerDriver.scheduled.last?.fire()

        XCTAssertEqual(harness.detectionEngine.startCount, 2)
    }

    func testCameraStallShowsModalAndListsDevices() {
        let expectation = expectation(description: "camera stall presenter")
        var presenterCalls = 0
        var presentedDevices: [CameraDeviceInfo] = []
        let harness = makeHarness(cameraDevices: [
            CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false),
            CameraDeviceInfo(id: "cam2", name: "External", isExternal: true)
        ], cameraStallPresenter: { devices, _, _, _, _ in
            presenterCalls += 1
            presentedDevices = devices
            expectation.fulfill()
        })
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        appState._testSetAwaitingCamera(true)
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 10)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(appState.isCameraStalled)
        XCTAssertEqual(presenterCalls, 1)
        XCTAssertEqual(harness.detectionEngine.startCount, 1)
        XCTAssertEqual(presentedDevices.count, 2)
    }

    func testCameraStallIsSuppressedWhilePermissionIsPending() {
        let expectation = expectation(description: "camera stall presenter")
        expectation.isInverted = true
        let harness = makeHarness(cameraStallPresenter: { _, _, _, _, _ in
            expectation.fulfill()
        }, cameraAuthorizationStatus: { .notDetermined })
        let appState = harness.appState

        appState._testSetAwaitingCamera(true)
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 10)

        wait(for: [expectation], timeout: 0.2)
        XCTAssertFalse(appState.isCameraStalled)
    }

    func testCameraStallDoesNotTriggerImmediatelyAfterPermissionGranted() {
        let expectation = expectation(description: "camera stall presenter")
        expectation.isInverted = true
        var status: AVAuthorizationStatus = .notDetermined
        let harness = makeHarness(cameraStallPresenter: { _, _, _, _, _ in
            expectation.fulfill()
        }, cameraAuthorizationStatus: { status })
        let appState = harness.appState

        appState._testSetAwaitingCamera(true)
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 10)

        status = .authorized
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 20)

        wait(for: [expectation], timeout: 0.2)
        XCTAssertFalse(appState.isCameraStalled)
    }

    func testPermissionGrantAutoStartsMonitoringAfterPrompt() {
        var requestCount = 0
        let harness = makeHarness(
            cameraAuthorizationStatus: { .notDetermined },
            requestCameraAccess: { completion in
                requestCount += 1
                completion(true)
            }
        )
        let appState = harness.appState

        appState._testRequestCameraAccessIfNeeded()
        XCTAssertEqual(requestCount, 1)

        let expectation = expectation(description: "auto start monitoring")
        DispatchQueue.main.async {
            if appState.isStarting {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(appState.isStarting)
        XCTAssertEqual(harness.detectionEngine.startCount, 1)
    }

    func testPermissionRequestUpdatesAwaitingPermissionStatus() {
        var capturedCompletion: ((Bool) -> Void)?
        let harness = makeHarness(
            cameraAuthorizationStatus: { .notDetermined },
            requestCameraAccess: { completion in
                capturedCompletion = completion
            }
        )
        let appState = harness.appState

        appState._testRequestCameraAccessIfNeeded()
        XCTAssertTrue(appState.isAwaitingCameraPermission)

        let expectation = expectation(description: "permission resolves")
        DispatchQueue.main.async {
            capturedCompletion?(false)
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(appState.isAwaitingCameraPermission)
    }

    func testToggleMonitoringCancelsPendingPermissionAutoStart() {
        var capturedCompletion: ((Bool) -> Void)?
        let harness = makeHarness(
            cameraAuthorizationStatus: { .notDetermined },
            requestCameraAccess: { completion in
                capturedCompletion = completion
            }
        )
        let appState = harness.appState

        appState._testRequestCameraAccessIfNeeded()
        XCTAssertTrue(appState.isAwaitingCameraPermission)

        appState.toggleMonitoring()
        XCTAssertFalse(appState.isAwaitingCameraPermission)
        XCTAssertEqual(harness.detectionEngine.startCount, 0)

        let expectation = expectation(description: "permission completion")
        DispatchQueue.main.async {
            capturedCompletion?(true)
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(harness.detectionEngine.startCount, 0)
    }

    func testPowerStateUpdatesFrameInterval() {
        let powerMonitor = TestPowerStateMonitor(state: .pluggedIn)
        let harness = makeHarness(powerStateMonitor: powerMonitor)

        guard let initialInterval = harness.detectionEngine.frameIntervalValues.last else {
            XCTFail("Missing initial frame interval")
            return
        }
        XCTAssertEqual(initialInterval, 1.0 / 10.0, accuracy: 0.0001)

        powerMonitor.send(.onBattery)
        guard let batteryInterval = harness.detectionEngine.frameIntervalValues.last else {
            XCTFail("Missing battery frame interval")
            return
        }
        XCTAssertEqual(batteryInterval, 1.0 / 5.0, accuracy: 0.0001)

        powerMonitor.send(.lowPower)
        guard let lowPowerInterval = harness.detectionEngine.frameIntervalValues.last else {
            XCTFail("Missing low power frame interval")
            return
        }
        XCTAssertEqual(lowPowerInterval, 1.0 / 2.0, accuracy: 0.0001)
    }

    func testCameraStallSelectionUpdatesCameraID() {
        let expectation = expectation(description: "camera stall selection")
        var selected: String?
        let harness = makeHarness(cameraStallPresenter: { _, _, _, _, onSelect in
            onSelect("cam2")
            selected = "cam2"
            expectation.fulfill()
        })
        let appState = harness.appState

        appState._testSetAwaitingCamera(true)
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 10)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(appState.settings.cameraID, "cam2")
        XCTAssertEqual(selected, "cam2")
    }

    func testCameraStallRetryClearsStalledStateWhenFramesResume() {
        let expectation = expectation(description: "camera stall retry")
        var retry: (() -> Void)?
        let harness = makeHarness(cameraStallPresenter: { _, _, _, onRetry, _ in
            retry = onRetry
            expectation.fulfill()
        })
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        appState._testSetAwaitingCamera(true)
        appState._testEvaluateCameraStall(now: harness.clock.mediaTime + 10)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(appState.isCameraStalled)

        retry?()
        XCTAssertEqual(harness.detectionEngine.startCount, 2)
        harness.detectionEngine.emitFrame()

        XCTAssertFalse(appState.isAwaitingCamera)
        XCTAssertFalse(appState.isCameraStalled)
    }

    func testStartAtLoginUsesLoginItemManager() {
        let harness = makeHarness()

        harness.settings.startAtLogin = true

        XCTAssertEqual(harness.loginItemManager.setEnabledValues, [true])
    }

    func testOpenCameraSettingsUsesHandler() {
        var opened = false
        let harness = makeHarness(openCameraSettings: { opened = true })

        harness.appState.openCameraSettings()

        XCTAssertTrue(opened)
    }

    func testTerminateAppUsesHandler() {
        var terminated = false
        let harness = makeHarness(terminateApp: { terminated = true })

        harness.appState.terminateApp()

        XCTAssertTrue(terminated)
    }

    func testResumeMonitoringStateMigration() {
        let suiteName = "HandsOffTests.AppState.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "settings.resumeMonitoringOnLaunch")

        let harness = makeHarness(defaults: defaults)

        _ = harness.appState

        XCTAssertTrue(defaults.bool(forKey: "state.resumeMonitoringOnLaunch"))
        XCTAssertNil(defaults.object(forKey: "settings.resumeMonitoringOnLaunch"))
    }

    func testWillSleepStopsMonitoringAndMarksResume() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)

        harness.workspaceNotificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

        XCTAssertFalse(appState.isMonitoring)
        XCTAssertEqual(harness.detectionEngine.stopCount, 1)
        XCTAssertTrue(harness.defaults.bool(forKey: "state.resumeMonitoringOnLaunch"))
    }

    func testDidWakeResumesMonitoringAfterDelay() {
        let harness = makeHarness()
        let appState = harness.appState

        appState.startMonitoring()
        harness.detectionEngine.completeStart(with: nil)
        harness.workspaceNotificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)

        harness.workspaceNotificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)

        XCTAssertEqual(harness.timerDriver.makeOneShotCount, 1)
        harness.timerDriver.scheduled.last?.fire()
        XCTAssertEqual(harness.detectionEngine.startCount, 2)
    }

    func testWakeGracePeriodSuppressesCameraStallAlert() {
        let harness = makeHarness()
        let appState = harness.appState

        harness.clock.mediaTime = 100
        harness.workspaceNotificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        appState._testSetAwaitingCamera(true)

        appState._testEvaluateCameraStall(now: 107)

        XCTAssertFalse(appState.isCameraStalled)

        appState._testEvaluateCameraStall(now: 120)

        XCTAssertTrue(appState.isCameraStalled)
    }

    private struct Harness {
        let appState: AppState
        let settings: SettingsStore
        let stats: StatsStore
        let cameraStore: TestCameraStore
        let alertManager: TestAlertManager
        let blurOverlay: TestBlurOverlay
        let loginItemManager: TestLoginItemManager
        let detectionEngine: TestDetectionEngine
        let clock: TestClockRef
        let workspaceNotificationCenter: NotificationCenter
        let defaults: UserDefaults
        let timerDriver: TestTimerDriver
        let activityCapture: ActivityCapture
    }

    private final class TestClockRef {
        var now: Date
        var mediaTime: CFTimeInterval

        init(now: Date, mediaTime: CFTimeInterval) {
            self.now = now
            self.mediaTime = mediaTime
        }
    }

    private func makeHarness(
        alertSoundEnabled: Bool = true,
        alertBannerEnabled: Bool = false,
        flashEnabled: Bool = true,
        cameraDevices: [CameraDeviceInfo] = [CameraDeviceInfo(id: "cam1", name: "Built-in", isExternal: false)],
        defaults: UserDefaults? = nil,
        openCameraSettings: (() -> Void)? = nil,
        terminateApp: (() -> Void)? = nil,
        cameraStallPresenter: CameraStallAlertPresenter? = nil,
        cameraAuthorizationStatus: (() -> AVAuthorizationStatus)? = nil,
        requestCameraAccess: (((@escaping (Bool) -> Void) -> Void))? = nil,
        powerStateMonitor: TestPowerStateMonitor? = nil
    ) -> Harness {
        let suiteName = "HandsOffTests.AppState.\(UUID().uuidString)"
        let resolvedDefaults: UserDefaults
        if let providedDefaults = defaults {
            resolvedDefaults = providedDefaults
        } else {
            resolvedDefaults = UserDefaults(suiteName: suiteName)!
            resolvedDefaults.removePersistentDomain(forName: suiteName)
        }

        let settings = SettingsStore(defaults: resolvedDefaults)
        settings.alertSoundEnabled = alertSoundEnabled
        settings.alertBannerEnabled = alertBannerEnabled
        settings.flashScreenOnTouch = flashEnabled
        settings.cameraID = cameraDevices.first?.id

        let stats = StatsStore(defaults: resolvedDefaults)
        let cameraStore = TestCameraStore(devices: cameraDevices)
        let alertManager = TestAlertManager()
        let blurOverlay = TestBlurOverlay()
        let loginItemManager = TestLoginItemManager()
        let detectionEngine = TestDetectionEngine()
        let clock = TestClockRef(now: Date(timeIntervalSince1970: 1_700_000_000), mediaTime: 0)
        let notificationCenter = NotificationCenter()
        let workspaceNotificationCenter = NotificationCenter()
        let timerDriverCapture = TestTimerDriver()
        let timerDriver = timerDriverCapture.makeDriver()
        let activityToken = NSObject()
        let activityCapture = ActivityCapture()
        let resolvedPowerStateMonitor = powerStateMonitor ?? TestPowerStateMonitor(state: .pluggedIn)
        let activityController = ActivityController(
            begin: { _ in
                activityCapture.beginCount += 1
                return activityToken
            },
            end: { _ in
                activityCapture.endCount += 1
            }
        )

        let dependencies = AppStateDependencies(
            settings: settings,
            stats: stats,
            cameraStore: cameraStore,
            alertManager: alertManager,
            blurOverlay: blurOverlay,
            loginItemManager: loginItemManager,
            detectionEngineFactory: { _, onTrigger in
                detectionEngine.triggerHandler = onTrigger
                return detectionEngine
            },
            userDefaults: resolvedDefaults,
            notificationCenter: notificationCenter,
            workspaceNotificationCenter: workspaceNotificationCenter,
            powerStateMonitor: resolvedPowerStateMonitor,
            timerDriver: timerDriver,
            now: { clock.now },
            mediaTime: { clock.mediaTime },
            cameraAuthorizationStatus: cameraAuthorizationStatus ?? { .authorized },
            requestCameraAccess: requestCameraAccess ?? { completion in
                completion(true)
            },
            openCameraSettings: openCameraSettings ?? {},
            terminateApp: terminateApp ?? {},
            activityController: activityController,
            cameraStallAlertPresenter: cameraStallPresenter ?? { _, _, _, _, _ in }
        )

        let appState = AppState(dependencies: dependencies)

        return Harness(
            appState: appState,
            settings: settings,
            stats: stats,
            cameraStore: cameraStore,
            alertManager: alertManager,
            blurOverlay: blurOverlay,
            loginItemManager: loginItemManager,
            detectionEngine: detectionEngine,
            clock: clock,
            workspaceNotificationCenter: workspaceNotificationCenter,
            defaults: resolvedDefaults,
            timerDriver: timerDriverCapture,
            activityCapture: activityCapture
        )
    }

    private final class ActivityCapture {
        var beginCount = 0
        var endCount = 0
    }

    private func makeImage() -> CGImage? {
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
        return context.makeImage()
    }
}
