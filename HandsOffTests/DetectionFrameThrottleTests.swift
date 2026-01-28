import XCTest
@testable import HandsOff

final class DetectionFrameThrottleTests: XCTestCase {
    func testThrottleSkipsFramesInsideInterval() {
        let eval = DetectionFrameThrottle.evaluate(
            now: 1.0,
            lastFrameTime: 0.95,
            frameInterval: 0.2,
            staleFrameThreshold: 1.0
        )

        XCTAssertFalse(eval.shouldProcess)
        XCTAssertFalse(eval.resetTrigger)
        XCTAssertEqual(eval.newLastFrameTime, 0.95, accuracy: 0.0001)
    }

    func testThrottleProcessesFramesOutsideInterval() {
        let eval = DetectionFrameThrottle.evaluate(
            now: 2.0,
            lastFrameTime: 1.0,
            frameInterval: 0.2,
            staleFrameThreshold: 1.0
        )

        XCTAssertTrue(eval.shouldProcess)
        XCTAssertFalse(eval.resetTrigger)
        XCTAssertEqual(eval.newLastFrameTime, 2.0, accuracy: 0.0001)
    }

    func testThrottleResetsTriggerWhenStale() {
        let eval = DetectionFrameThrottle.evaluate(
            now: 5.0,
            lastFrameTime: 1.0,
            frameInterval: 0.2,
            staleFrameThreshold: 2.0
        )

        XCTAssertTrue(eval.shouldProcess)
        XCTAssertTrue(eval.resetTrigger)
    }
}
