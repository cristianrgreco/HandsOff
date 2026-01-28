import AVFoundation
import XCTest
@testable import HandsOff

final class DetectionEngineRestartTests: XCTestCase {
    private func makeEngine(onTrigger: @escaping () -> Void = {}) -> DetectionEngine {
        DetectionEngine(
            settingsProvider: { DetectionSettings(cameraID: nil, faceZoneScale: 1.0) },
            onTrigger: onTrigger
        )
    }

    func testRuntimeErrorRestartsSession() {
        let engine = makeEngine()
        var restartCount = 0
        engine._testSetRestartHandler { restartCount += 1 }
        engine._testSetIsRunning(true)

        let notification = Notification(
            name: .AVCaptureSessionRuntimeError,
            object: nil,
            userInfo: [AVCaptureSessionErrorKey: NSError(domain: "test", code: 1)]
        )

        engine._testHandleRuntimeError(notification)

        XCTAssertEqual(restartCount, 1)
    }

    func testRuntimeErrorWithoutErrorDoesNotRestart() {
        let engine = makeEngine()
        var restartCount = 0
        engine._testSetRestartHandler { restartCount += 1 }
        engine._testSetIsRunning(true)

        let notification = Notification(name: .AVCaptureSessionRuntimeError, object: nil, userInfo: [:])

        engine._testHandleRuntimeError(notification)

        XCTAssertEqual(restartCount, 0)
    }

    func testStallRestartsSession() {
        let engine = makeEngine()
        var restartCount = 0
        engine._testSetRestartHandler { restartCount += 1 }
        engine._testSetIsRunning(true)
        engine._testSetLastFrameTime(1.0)

        engine._testEvaluateStall(now: 5.0, stallThreshold: 2.5)

        XCTAssertEqual(restartCount, 1)
    }

    func testTriggerFiresOnlyOnHitEdge() {
        var triggerCount = 0
        let engine = makeEngine { triggerCount += 1 }

        engine._testUpdateHit(true)
        engine._testUpdateHit(true)
        engine._testUpdateHit(false)
        engine._testUpdateHit(true)

        XCTAssertEqual(triggerCount, 2)
    }
}
