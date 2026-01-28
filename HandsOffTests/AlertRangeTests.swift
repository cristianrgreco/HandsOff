import XCTest
@testable import HandsOff

final class AlertRangeTests: XCTestCase {
    func testLabelsAndTimingValues() {
        XCTAssertEqual(AlertRange.hour.label, "Hour")
        XCTAssertEqual(AlertRange.day.label, "Day")
        XCTAssertEqual(AlertRange.week.label, "Week")

        XCTAssertEqual(AlertRange.hour.window, 60 * 60)
        XCTAssertEqual(AlertRange.day.window, 24 * 60 * 60)
        XCTAssertEqual(AlertRange.week.window, 7 * 24 * 60 * 60)

        XCTAssertEqual(AlertRange.hour.bucket, 60)
        XCTAssertEqual(AlertRange.day.bucket, 60 * 60)
        XCTAssertEqual(AlertRange.week.bucket, 24 * 60 * 60)

        XCTAssertEqual(AlertRange.hour.refreshInterval, 15)
        XCTAssertEqual(AlertRange.day.refreshInterval, 60)
        XCTAssertEqual(AlertRange.week.refreshInterval, 300)
    }
}
