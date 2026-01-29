import XCTest
@testable import HandsOff

final class MenuBarStatusTests: XCTestCase {
    func testStatusTextAndTone() {
        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: false,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            "Monitoring off"
        )
        XCTAssertEqual(
            MenuBarStatus.statusTone(
                isMonitoring: false,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            .secondary
        )

        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: false,
                isStarting: true,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            "Starting..."
        )
        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: false,
                isStarting: false,
                isAwaitingCamera: true,
                isSnoozed: false,
                isCameraStalled: false
            ),
            "Starting..."
        )
        XCTAssertEqual(
            MenuBarStatus.statusTone(
                isMonitoring: false,
                isStarting: true,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            .orange
        )

        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: true,
                isCameraStalled: false
            ),
            "Monitoring snoozed"
        )
        XCTAssertEqual(
            MenuBarStatus.statusTone(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: true,
                isCameraStalled: false
            ),
            .orange
        )

        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: true
            ),
            "Camera not responding"
        )
        XCTAssertEqual(
            MenuBarStatus.statusTone(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: true
            ),
            .red
        )

        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            "Monitoring on"
        )
        XCTAssertEqual(
            MenuBarStatus.statusTone(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false,
                isCameraStalled: false
            ),
            .green
        )
    }

    func testStatusTextShowsPermissionPromptWhenAwaitingPermission() {
        XCTAssertEqual(
            MenuBarStatus.statusText(
                isMonitoring: false,
                isStarting: true,
                isAwaitingCamera: true,
                isSnoozed: false,
                isCameraStalled: false,
                isAwaitingPermission: true
            ),
            "Waiting for camera permission..."
        )
    }

    func testSymbols() {
        XCTAssertEqual(
            MenuBarStatus.menuBarSymbolName(
                isMonitoring: false,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false
            ),
            "hand.raised.slash"
        )
        XCTAssertEqual(
            MenuBarStatus.menuBarSymbolName(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: true
            ),
            "hand.raised.slash.fill"
        )
        XCTAssertEqual(
            MenuBarStatus.headerSymbolName(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: false
            ),
            "hand.raised.fill"
        )
        XCTAssertEqual(
            MenuBarStatus.headerSymbolName(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                isSnoozed: true
            ),
            "hand.raised.slash.fill"
        )
        XCTAssertEqual(
            MenuBarStatus.headerSymbolName(
                isMonitoring: false,
                isStarting: true,
                isAwaitingCamera: false,
                isSnoozed: false
            ),
            "hand.raised"
        )
    }

    func testPrimaryActionTitle() {
        XCTAssertEqual(MenuBarStatus.primaryActionTitle(isMonitoring: false, isStarting: false), "Start")
        XCTAssertEqual(MenuBarStatus.primaryActionTitle(isMonitoring: false, isStarting: true), "Cancel")
        XCTAssertEqual(MenuBarStatus.primaryActionTitle(isMonitoring: true, isStarting: false), "Stop")
    }

    func testPreviewPlaceholderText() {
        XCTAssertEqual(
            MenuBarStatus.previewPlaceholderText(
                isMonitoring: false,
                isStarting: false,
                isAwaitingCamera: false,
                hasPreviewImage: false
            ),
            "Start monitoring to show the camera feed."
        )
        XCTAssertEqual(
            MenuBarStatus.previewPlaceholderText(
                isMonitoring: false,
                isStarting: true,
                isAwaitingCamera: false,
                hasPreviewImage: false
            ),
            "Starting camera..."
        )
        XCTAssertEqual(
            MenuBarStatus.previewPlaceholderText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: true,
                hasPreviewImage: false
            ),
            "Starting camera..."
        )
        XCTAssertEqual(
            MenuBarStatus.previewPlaceholderText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                hasPreviewImage: false
            ),
            "Waiting for camera..."
        )
        XCTAssertNil(
            MenuBarStatus.previewPlaceholderText(
                isMonitoring: true,
                isStarting: false,
                isAwaitingCamera: false,
                hasPreviewImage: true
            )
        )
    }

    func testShouldEnablePreview() {
        XCTAssertTrue(MenuBarStatus.shouldEnablePreview(isMonitoring: true, isAwaitingCamera: false))
        XCTAssertFalse(MenuBarStatus.shouldEnablePreview(isMonitoring: true, isAwaitingCamera: true))
        XCTAssertFalse(MenuBarStatus.shouldEnablePreview(isMonitoring: false, isAwaitingCamera: false))
    }

    func testShouldShowOpenCameraSettings() {
        XCTAssertTrue(MenuBarStatus.shouldShowOpenCameraSettings(error: .permissionDenied))
        XCTAssertFalse(MenuBarStatus.shouldShowOpenCameraSettings(error: .noCamera))
        XCTAssertFalse(MenuBarStatus.shouldShowOpenCameraSettings(error: nil))
    }
}
