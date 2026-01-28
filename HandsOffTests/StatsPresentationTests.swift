import XCTest
@testable import HandsOff

final class StatsPresentationTests: XCTestCase {
    func testPointsFilterZeroCounts() {
        let buckets = [
            AlertBucket(date: Date(), count: 0),
            AlertBucket(date: Date().addingTimeInterval(60), count: 2)
        ]

        let points = StatsPresentation.points(from: buckets)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.count, 2)
    }

    func testMaxCountDefaultsToOne() {
        let buckets = [AlertBucket(date: Date(), count: 0)]

        XCTAssertEqual(StatsPresentation.maxCount(from: buckets), 1)
    }

    func testMaxCountReturnsMaximum() {
        let buckets = [
            AlertBucket(date: Date(), count: 2),
            AlertBucket(date: Date().addingTimeInterval(60), count: 5),
            AlertBucket(date: Date().addingTimeInterval(120), count: 1)
        ]

        XCTAssertEqual(StatsPresentation.maxCount(from: buckets), 5)
    }
}
