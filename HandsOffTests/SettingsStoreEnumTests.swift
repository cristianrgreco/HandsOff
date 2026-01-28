import XCTest
@testable import HandsOff

final class SettingsStoreEnumTests: XCTestCase {
    func testSensitivityProperties() {
        XCTAssertEqual(Sensitivity.low.label, "Low")
        XCTAssertEqual(Sensitivity.medium.label, "Medium")
        XCTAssertEqual(Sensitivity.high.label, "High")

        XCTAssertEqual(Sensitivity.low.zoneExpansion, -0.06, accuracy: 0.0001)
        XCTAssertEqual(Sensitivity.medium.zoneExpansion, 0.20, accuracy: 0.0001)
        XCTAssertEqual(Sensitivity.high.zoneExpansion, 0.28, accuracy: 0.0001)

        XCTAssertEqual(Sensitivity.low.debounceWindow, 5)
        XCTAssertEqual(Sensitivity.medium.debounceWindow, 3)
        XCTAssertEqual(Sensitivity.high.debounceWindow, 2)

        XCTAssertEqual(Sensitivity.low.hitThreshold, 3)
        XCTAssertEqual(Sensitivity.medium.hitThreshold, 2)
        XCTAssertEqual(Sensitivity.high.hitThreshold, 1)
    }

    func testAlertTypeProperties() {
        XCTAssertEqual(AlertType.chime.label, "Sound")
        XCTAssertEqual(AlertType.banner.label, "Banner")
        XCTAssertEqual(AlertType.both.label, "Both")
        XCTAssertEqual(AlertType.off.label, "Off")

        XCTAssertTrue(AlertType.chime.usesSound)
        XCTAssertFalse(AlertType.chime.usesBanner)

        XCTAssertFalse(AlertType.banner.usesSound)
        XCTAssertTrue(AlertType.banner.usesBanner)

        XCTAssertTrue(AlertType.both.usesSound)
        XCTAssertTrue(AlertType.both.usesBanner)

        XCTAssertFalse(AlertType.off.usesSound)
        XCTAssertFalse(AlertType.off.usesBanner)
    }
}
