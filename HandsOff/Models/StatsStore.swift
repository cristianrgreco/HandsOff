import Foundation

final class StatsStore: ObservableObject {
    @Published private(set) var alertsToday: Int
    @Published private(set) var monitoringSecondsToday: Int
    @Published private(set) var touchFreeStreakDays: Int

    private let defaults: UserDefaults
    private var currentDateKey: String
    private var monitoringStart: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.currentDateKey = defaults.string(forKey: Keys.currentDateKey) ?? Self.dateKey(Date())
        self.alertsToday = defaults.integer(forKey: Keys.alertsToday)
        self.monitoringSecondsToday = defaults.integer(forKey: Keys.monitoringSecondsToday)
        self.touchFreeStreakDays = defaults.integer(forKey: Keys.touchFreeStreakDays)
        self.monitoringStart = nil

        rolloverIfNeeded()
    }

    func recordAlert() {
        rolloverIfNeeded()
        alertsToday += 1
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
    }
}
