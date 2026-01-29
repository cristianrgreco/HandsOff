import XCTest
@testable import HandsOff

final class StatsStoreTests: XCTestCase {
    func testRecordAlertIncrementsTodayAndBuckets() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        store.recordAlert(now: now)

        XCTAssertEqual(store.alertsToday, 1)
        XCTAssertEqual(store._testAlertHistory.count, 1)
        let buckets = store.alertBuckets(for: .hour, now: now)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.count }, 1)
    }

    func testRolloverResetsCountsAndAdvancesTouchFreeStreak() {
        let defaults = makeDefaults()
        let yesterday = Date(timeIntervalSince1970: 1_700_000_000 - 86_400)
        defaults.set(dateKey(yesterday), forKey: "stats.currentDateKey")
        defaults.set(0, forKey: "stats.alertsToday")
        defaults.set(3_600, forKey: "stats.monitoringSecondsToday")
        defaults.set(2, forKey: "stats.touchFreeStreakDays")

        let store = StatsStore(defaults: defaults)

        XCTAssertEqual(store.alertsToday, 0)
        XCTAssertEqual(store.monitoringSecondsToday, 0)
        XCTAssertEqual(store.touchFreeStreakDays, 3)
    }

    func testHistoryPrunesAlertsOlderThanSevenDays() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oldTimestamp = now.addingTimeInterval(-(8 * 24 * 60 * 60)).timeIntervalSince1970
        defaults.set([oldTimestamp], forKey: "stats.alertHistory")

        let store = StatsStore(defaults: defaults)

        let buckets = store.alertBuckets(for: .week, now: now)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.count }, 0)
    }

    func testMonitoringTimeAccumulatesBetweenBeginAndEnd() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(123)

        store.beginMonitoring(now: start)
        store.endMonitoring(now: end)

        XCTAssertEqual(store.monitoringSecondsToday, 123)
    }

    func testTouchFreeStreakResetsWhenAlertsOccurred() {
        let defaults = makeDefaults()
        let yesterday = Date(timeIntervalSince1970: 1_700_000_000 - 86_400)
        defaults.set(dateKey(yesterday), forKey: "stats.currentDateKey")
        defaults.set(1, forKey: "stats.alertsToday")
        defaults.set(3_600, forKey: "stats.monitoringSecondsToday")
        defaults.set(5, forKey: "stats.touchFreeStreakDays")

        let store = StatsStore(defaults: defaults)

        XCTAssertEqual(store.touchFreeStreakDays, 0)
    }

    func testHourBucketsCountMatchesWindow() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let buckets = store.alertBuckets(for: .hour, now: now)

        XCTAssertEqual(buckets.count, 60)
    }

    func testDayAndWeekBucketsCountMatchesWindow() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertEqual(store.alertBuckets(for: .day, now: now).count, 24)
        XCTAssertEqual(store.alertBuckets(for: .week, now: now).count, 7)
    }

    func testMonitoringRolloverAcrossMidnightAccumulatesNewDay() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone.current
        components.year = 2023
        components.month = 1
        components.day = 1
        components.hour = 23
        components.minute = 59
        components.second = 0
        let start = calendar.date(from: components)!
        let end = start.addingTimeInterval(120)

        store.beginMonitoring(now: start)
        store.endMonitoring(now: end)

        XCTAssertEqual(store.monitoringSecondsToday, 60)
    }

    func testBeginMonitoringDoesNotOverrideExistingStart() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let second = start.addingTimeInterval(10)

        store.beginMonitoring(now: start)
        store.beginMonitoring(now: second)

        XCTAssertEqual(store._testMonitoringStart, start)
    }

    func testEndMonitoringWithoutStartIsNoop() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)

        store.endMonitoring(now: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(store.monitoringSecondsToday, 0)
    }

    func testBucketAlignment() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let now = Date()

        let hourBuckets = store.alertBuckets(for: .hour, now: now)
        XCTAssertTrue(hourBuckets.allSatisfy { Calendar.current.component(.second, from: $0.date) == 0 })

        let dayBuckets = store.alertBuckets(for: .day, now: now)
        XCTAssertTrue(dayBuckets.allSatisfy { Calendar.current.component(.minute, from: $0.date) == 0 })
        XCTAssertTrue(dayBuckets.allSatisfy { Calendar.current.component(.second, from: $0.date) == 0 })

        let weekBuckets = store.alertBuckets(for: .week, now: now)
        XCTAssertTrue(weekBuckets.allSatisfy { Calendar.current.component(.hour, from: $0.date) == 0 })
        XCTAssertTrue(weekBuckets.allSatisfy { Calendar.current.component(.minute, from: $0.date) == 0 })
        XCTAssertTrue(weekBuckets.allSatisfy { Calendar.current.component(.second, from: $0.date) == 0 })
    }

    func testAlertBucketsIgnoreEventsOutsideWindow() {
        let defaults = makeDefaults()
        let now = Date()
        let recent = now.addingTimeInterval(-30 * 60).timeIntervalSince1970
        let old = now.addingTimeInterval(-2 * 60 * 60).timeIntervalSince1970
        defaults.set([recent, old], forKey: "stats.alertHistory")

        let store = StatsStore(defaults: defaults)
        let buckets = store.alertBuckets(for: .hour, now: now)

        XCTAssertEqual(buckets.reduce(0) { $0 + $1.count }, 1)
    }

    func testResetAllClearsHistoryAndCounts() {
        let defaults = makeDefaults()
        let store = StatsStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        store.recordAlert(now: now)
        store.beginMonitoring(now: now)
        store.endMonitoring(now: now.addingTimeInterval(45))
        store.resetAll(now: now)

        XCTAssertEqual(store.alertsToday, 0)
        XCTAssertEqual(store.monitoringSecondsToday, 0)
        XCTAssertEqual(store.touchFreeStreakDays, 0)
        XCTAssertEqual(store.alertBuckets(for: .day, now: now).reduce(0) { $0 + $1.count }, 0)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "HandsOffTests.StatsStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
