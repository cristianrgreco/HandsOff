import AVFoundation
import XCTest
@testable import HandsOff

final class DetectionSessionHealthTests: XCTestCase {
    func testRestartForStallWhenFrameIsStale() {
        XCTAssertTrue(DetectionSessionHealth.shouldRestartForStall(
            lastFrameTime: 1.0,
            now: 5.0,
            stallThreshold: 2.5
        ))
    }

    func testNoRestartForFreshFrames() {
        XCTAssertFalse(DetectionSessionHealth.shouldRestartForStall(
            lastFrameTime: 4.0,
            now: 5.0,
            stallThreshold: 2.5
        ))
    }

    func testRestartForRuntimeErrorWhenNotificationHasError() {
        let notification = Notification(
            name: .AVCaptureSessionRuntimeError,
            object: nil,
            userInfo: [AVCaptureSessionErrorKey: NSError(domain: "test", code: 1)]
        )

        XCTAssertTrue(DetectionSessionHealth.shouldRestartForRuntimeError(notification))
    }

    func testNoRestartForRuntimeErrorWithoutErrorInfo() {
        let notification = Notification(name: .AVCaptureSessionRuntimeError, object: nil, userInfo: [:])

        XCTAssertFalse(DetectionSessionHealth.shouldRestartForRuntimeError(notification))
    }
}
