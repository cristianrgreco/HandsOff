import Foundation

enum AlertRange: String, CaseIterable, Identifiable {
    case hour
    case day
    case week

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hour: return "Hour"
        case .day: return "Day"
        case .week: return "Week"
        }
    }

    var window: TimeInterval {
        switch self {
        case .hour: return 60 * 60
        case .day: return 24 * 60 * 60
        case .week: return 7 * 24 * 60 * 60
        }
    }

    var bucket: TimeInterval {
        switch self {
        case .hour: return 60
        case .day: return 60 * 60
        case .week: return 24 * 60 * 60
        }
    }

    var refreshInterval: TimeInterval {
        switch self {
        case .hour: return 15
        case .day: return 60
        case .week: return 300
        }
    }
}

struct AlertBucket: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

final class StatsStore: ObservableObject {
    @Published private(set) var alertsToday: Int
    @Published private(set) var monitoringSecondsToday: Int
    @Published private(set) var touchFreeStreakDays: Int

    private let defaults: UserDefaults
    private var currentDateKey: String
    private var monitoringStart: Date?
    private var alertHistory: [TimeInterval]
    private let historyRetention: TimeInterval = 7 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.currentDateKey = defaults.string(forKey: Keys.currentDateKey) ?? Self.dateKey(Date())
        self.alertsToday = defaults.integer(forKey: Keys.alertsToday)
        self.monitoringSecondsToday = defaults.integer(forKey: Keys.monitoringSecondsToday)
        self.touchFreeStreakDays = defaults.integer(forKey: Keys.touchFreeStreakDays)
        self.monitoringStart = nil
        self.alertHistory = defaults.array(forKey: Keys.alertHistory) as? [TimeInterval] ?? []

        rolloverIfNeeded()
        pruneHistory()
    }

    func recordAlert(now: Date = Date()) {
        rolloverIfNeeded(now: now)
        alertsToday += 1
        alertHistory.append(now.timeIntervalSince1970)
        pruneHistory(now: now)
        saveHistory()
        save()
    }

    func beginMonitoring(now: Date = Date()) {
        rolloverIfNeeded(now: now)
        guard monitoringStart == nil else { return }
        monitoringStart = now
        save()
    }

    func endMonitoring(now: Date = Date()) {
        rolloverIfNeeded(now: now)
        guard let monitoringStart else { return }
        let elapsed = max(0, now.timeIntervalSince(monitoringStart))
        monitoringSecondsToday += Int(elapsed.rounded())
        self.monitoringStart = nil
        save()
    }

    var formattedMonitoringTime: String {
        let formatter = Self.durationFormatter
        return formatter.string(from: TimeInterval(currentMonitoringSeconds)) ?? "0m"
    }

    func alertBuckets(for range: AlertRange, now: Date = Date()) -> [AlertBucket] {
        pruneHistory(now: now)
        let end = alignedEnd(for: range, now: now)
        let start = end.addingTimeInterval(-range.window)
        let bucketCount = max(1, Int(range.window / range.bucket))
        var counts = Array(repeating: 0, count: bucketCount)

        for timestamp in alertHistory where timestamp >= start.timeIntervalSince1970 {
            let offset = timestamp - start.timeIntervalSince1970
            let index = Int(offset / range.bucket)
            if index >= 0 && index < counts.count {
                counts[index] += 1
            }
        }

        return counts.enumerated().map { index, count in
            let date = start.addingTimeInterval(range.bucket * Double(index))
            return AlertBucket(date: date, count: count)
        }
    }

    private func alignedEnd(for range: AlertRange, now: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        switch range {
        case .hour:
            return calendar.date(bySetting: .second, value: 0, of: now) ?? now
        case .day:
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? now
        case .week:
            return calendar.startOfDay(for: now)
        }
    }

    func resetAll(now: Date = Date()) {
        currentDateKey = Self.dateKey(now)
        alertsToday = 0
        monitoringSecondsToday = 0
        touchFreeStreakDays = 0
        monitoringStart = nil
        alertHistory.removeAll()
        saveHistory()
        save()
    }

    private var currentMonitoringSeconds: Int {
        rolloverIfNeeded()
        if let monitoringStart {
            let elapsed = max(0, Date().timeIntervalSince(monitoringStart))
            return monitoringSecondsToday + Int(elapsed.rounded())
        }
        return monitoringSecondsToday
    }

    private func rolloverIfNeeded(now: Date = Date()) {
        let todayKey = Self.dateKey(now)
        guard todayKey != currentDateKey else { return }

        if let monitoringStart {
            let calendar = Calendar(identifier: .gregorian)
            let midnight = calendar.startOfDay(for: now)
            let elapsed = max(0, midnight.timeIntervalSince(monitoringStart))
            monitoringSecondsToday += Int(elapsed.rounded())
            self.monitoringStart = midnight
        }

        let completedTouchFreeDay = alertsToday == 0 && monitoringSecondsToday > 0
        if completedTouchFreeDay {
            touchFreeStreakDays += 1
        } else {
            touchFreeStreakDays = 0
        }

        currentDateKey = todayKey
        alertsToday = 0
        monitoringSecondsToday = 0
        save()
    }

    private func save() {
        defaults.set(currentDateKey, forKey: Keys.currentDateKey)
        defaults.set(alertsToday, forKey: Keys.alertsToday)
        defaults.set(monitoringSecondsToday, forKey: Keys.monitoringSecondsToday)
        defaults.set(touchFreeStreakDays, forKey: Keys.touchFreeStreakDays)
    }

    private func saveHistory() {
        defaults.set(alertHistory, forKey: Keys.alertHistory)
    }

    private func pruneHistory(now: Date = Date()) {
        let cutoff = now.timeIntervalSince1970 - historyRetention
        if alertHistory.isEmpty { return }
        alertHistory = alertHistory.filter { $0 >= cutoff }
    }

    private static func dateKey(_ date: Date) -> String {
        let formatter = Self.dateFormatter
        return formatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private enum Keys {
        static let currentDateKey = "stats.currentDateKey"
        static let alertsToday = "stats.alertsToday"
        static let monitoringSecondsToday = "stats.monitoringSecondsToday"
        static let touchFreeStreakDays = "stats.touchFreeStreakDays"
        static let alertHistory = "stats.alertHistory"
    }
}

#if DEBUG
extension StatsStore {
    var _testMonitoringStart: Date? {
        monitoringStart
    }

    var _testAlertHistory: [TimeInterval] {
        alertHistory
    }
}
#endif
