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
}
