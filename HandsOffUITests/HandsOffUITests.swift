import XCTest

final class HandsOffUITests: XCTestCase {
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launchEnvironment = environment
        app.launch()
        app.activate()
        return app
    }

    private func mainWindow(in app: XCUIApplication) -> XCUIElement {
        let window = app.windows["Hands Off"]
        XCTAssertTrue(window.waitForExistence(timeout: 2))
        return window
    }

    private func element(_ identifier: String, in window: XCUIElement) -> XCUIElement {
        window.descendants(matching: .any)[identifier]
    }

    private func textValue(_ element: XCUIElement) -> String {
        if !element.label.isEmpty {
            return element.label
        }
        return element.value as? String ?? ""
    }

    func testLaunchShowsMonitoringOffStatus() {
        let app = launchApp()
        let window = mainWindow(in: app)
        let status = window.staticTexts["status-text"]
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(status), "Monitoring off")
        XCTAssertEqual(window.buttons["primary-action"].label, "Start")
        let placeholder = window.staticTexts["preview-placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(placeholder), "Start monitoring to show the camera feed.")
    }

    func testStartingShowsCancelAndPlaceholder() {
        let app = launchApp(environment: ["UITEST_START_DELAY": "5"])
        let window = mainWindow(in: app)
        let primary = window.buttons["primary-action"]
        XCTAssertTrue(primary.waitForExistence(timeout: 2))
        primary.click()

        let status = window.staticTexts["status-text"]
        let statusPredicate = NSPredicate(
            format: "label == %@ OR value == %@ OR label == %@ OR value == %@",
            "Starting...",
            "Starting...",
            "Monitoring on",
            "Monitoring on"
        )
        expectation(for: statusPredicate, evaluatedWith: status)
        waitForExpectations(timeout: 2)

        let actionLabel = window.buttons["primary-action"].label
        XCTAssertTrue(actionLabel == "Cancel" || actionLabel == "Stop")
        let placeholder = window.staticTexts["preview-placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 2))
        let placeholderValue = textValue(placeholder)
        XCTAssertTrue(placeholderValue == "Starting camera..." || placeholderValue == "Waiting for camera...")

        window.buttons["primary-action"].click()
        let offPredicate = NSPredicate(format: "label == %@ OR value == %@", "Monitoring off", "Monitoring off")
        expectation(for: offPredicate, evaluatedWith: status)
        waitForExpectations(timeout: 3)
    }

    func testStartMonitoringShowsMonitoringOnStatus() {
        let app = launchApp(environment: ["UITEST_START_ERROR": "none", "UITEST_PREVIEW": "0"])
        let window = mainWindow(in: app)
        let startButton = window.buttons["primary-action"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        startButton.click()

        let status = window.staticTexts["status-text"]
        let predicate = NSPredicate(format: "label == %@ OR value == %@", "Monitoring on", "Monitoring on")
        expectation(for: predicate, evaluatedWith: status)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(window.buttons["primary-action"].label, "Stop")

        let placeholder = window.staticTexts["preview-placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 2))
        let placeholderValue = textValue(placeholder)
        XCTAssertTrue(placeholderValue == "Waiting for camera..." || placeholderValue == "Starting camera...")
    }

    func testAwaitingCameraShowsStartingPlaceholder() {
        let app = launchApp(environment: ["UITEST_EMIT_FRAME": "0"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let status = window.staticTexts["status-text"]
        let startingPredicate = NSPredicate(format: "label == %@ OR value == %@", "Starting...", "Starting...")
        expectation(for: startingPredicate, evaluatedWith: status)
        waitForExpectations(timeout: 2)

        let stopPredicate = NSPredicate(format: "label == %@", "Stop")
        expectation(for: stopPredicate, evaluatedWith: window.buttons["primary-action"])
        waitForExpectations(timeout: 2)

        let placeholder = window.staticTexts["preview-placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(placeholder), "Starting camera...")
    }

    func testStopMonitoringReturnsToOff() {
        let app = launchApp(environment: ["UITEST_START_ERROR": "none", "UITEST_PREVIEW": "0"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let status = window.staticTexts["status-text"]
        let onPredicate = NSPredicate(format: "label == %@ OR value == %@", "Monitoring on", "Monitoring on")
        expectation(for: onPredicate, evaluatedWith: status)
        waitForExpectations(timeout: 2)

        window.buttons["primary-action"].click()
        let offPredicate = NSPredicate(format: "label == %@ OR value == %@", "Monitoring off", "Monitoring off")
        expectation(for: offPredicate, evaluatedWith: status)
        waitForExpectations(timeout: 2)
        XCTAssertEqual(window.buttons["primary-action"].label, "Start")
    }

    func testPermissionDeniedShowsCameraSettings() {
        let app = launchApp(environment: ["UITEST_START_ERROR": "permissionDenied"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let error = window.staticTexts["error-text"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(error), "Camera access is denied. Enable it in System Settings.")
        XCTAssertTrue(window.buttons["open-camera-settings"].exists)
    }

    func testNoCameraShowsError() {
        let app = launchApp(environment: ["UITEST_START_ERROR": "noCamera"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let error = window.staticTexts["error-text"]
        XCTAssertTrue(error.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(error), "No camera found.")
    }

    func testSettingsCameraPlaceholderWhenNoDevices() {
        let app = launchApp(environment: ["UITEST_CAMERA_DEVICES": "none"])
        let window = mainWindow(in: app)
        let placeholder = window.staticTexts["camera-placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(placeholder), "Camera: none detected")
    }

    func testSettingsCameraPickerWhenDevicesPresent() {
        let app = launchApp(environment: ["UITEST_CAMERA_DEVICES": "default"])
        let window = mainWindow(in: app)
        let picker = window.popUpButtons["camera-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 2))
    }

    func testStatsTodayCountVisible() {
        let app = launchApp()
        let window = mainWindow(in: app)
        let today = window.staticTexts["alerts-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(today), "0")
        XCTAssertTrue(window.otherElements["alerts-chart"].exists)
    }

    func testPreviewOverlayShowsAlertAndPoints() {
        let app = launchApp(environment: ["UITEST_HIT": "1"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let alert = window.staticTexts["alert-label"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(alert), "ALERT")
        XCTAssertTrue(window.otherElements["face-box"].exists)
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "hand-point-")
        XCTAssertGreaterThan(window.otherElements.matching(predicate).count, 0)
    }

    func testFPSBadgeHiddenWhenNotMonitoring() {
        let app = launchApp()
        let window = mainWindow(in: app)

        XCTAssertFalse(element("fps-badge", in: window).exists)
    }

    func testFPSBadgeShowsLowPowerRate() {
        let app = launchApp(environment: [
            "UITEST_POWER_STATE": "low",
            "UITEST_START_ERROR": "none"
        ])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let badge = element("fps-badge", in: window)
        XCTAssertTrue(badge.waitForExistence(timeout: 2))
        XCTAssertEqual(textValue(badge), "2 FPS")
    }

    func testStatsTodayCountIncrementsOnHit() {
        let app = launchApp(environment: ["UITEST_HIT": "1"])
        let window = mainWindow(in: app)
        window.buttons["primary-action"].click()

        let today = window.staticTexts["alerts-today"]
        let predicate = NSPredicate(format: "label == %@ OR value == %@", "1", "1")
        expectation(for: predicate, evaluatedWith: today)
        waitForExpectations(timeout: 2)
    }
}
