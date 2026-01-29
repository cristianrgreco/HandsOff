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

    func testChartDomainSpansBucketRange() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let buckets = [
            AlertBucket(date: start, count: 0),
            AlertBucket(date: start.addingTimeInterval(60), count: 1),
            AlertBucket(date: start.addingTimeInterval(120), count: 0)
        ]

        let domain = StatsPresentation.chartDomain(for: buckets, range: .hour, now: start)

        XCTAssertEqual(domain.lowerBound, start)
        XCTAssertEqual(domain.upperBound, start.addingTimeInterval(180))
    }

    func testChartDomainFallsBackToWindowWhenEmpty() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let domain = StatsPresentation.chartDomain(for: [], range: .hour, now: now)

        XCTAssertEqual(domain.lowerBound, now.addingTimeInterval(-AlertRange.hour.window))
        XCTAssertEqual(domain.upperBound, now)
    }

    func testXAxisLabelFormatsHourRange() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        let label = StatsPresentation.xAxisLabel(
            for: date,
            range: .hour,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(normalizedTimeLabel(label), "10:13 PM")
    }

    func testXAxisLabelFormatsDayRange() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        let label = StatsPresentation.xAxisLabel(
            for: date,
            range: .day,
            locale: locale,
            timeZone: timeZone
        )

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE jm")

        XCTAssertEqual(normalizedTimeLabel(label), normalizedTimeLabel(formatter.string(from: date)))
    }

    func testXAxisLabelFormatsWeekRange() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        let label = StatsPresentation.xAxisLabel(
            for: date,
            range: .week,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(label, "Nov 14")
    }

    private func normalizedTimeLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
