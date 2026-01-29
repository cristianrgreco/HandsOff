import Foundation

struct StatsPresentation {
    static func points(from buckets: [AlertBucket]) -> [AlertBucket] {
        buckets.filter { $0.count > 0 }
    }

    static func maxCount(from buckets: [AlertBucket]) -> Int {
        max(1, buckets.map(\.count).max() ?? 1)
    }

    static func chartDomain(for buckets: [AlertBucket], range: AlertRange, now: Date = Date()) -> ClosedRange<Date> {
        guard let first = buckets.first, let last = buckets.last else {
            return now.addingTimeInterval(-range.window)...now
        }
        let end = last.date.addingTimeInterval(range.bucket)
        return first.date...end
    }

    static func xAxisLabel(
        for date: Date,
        range: AlertRange,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        switch range {
        case .hour:
            formatter.setLocalizedDateFormatFromTemplate("jm")
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("EEE jm")
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        }

        return formatter.string(from: date)
    }
}
