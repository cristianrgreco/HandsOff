import XCTest
@testable import HandsOff

final class DetectionTriggerStateTests: XCTestCase {
    func testTriggerFiresOnlyOnHitStart() {
        var state = DetectionTriggerState()

        XCTAssertTrue(state.update(hit: true))
        XCTAssertFalse(state.update(hit: true))
        XCTAssertFalse(state.update(hit: true))
        XCTAssertFalse(state.update(hit: false))
        XCTAssertTrue(state.update(hit: true))
    }

    func testResetClearsActiveState() {
        var state = DetectionTriggerState()
        _ = state.update(hit: true)

        state.reset()

        XCTAssertTrue(state.update(hit: true))
    }
}
