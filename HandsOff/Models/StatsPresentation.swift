import Foundation

struct StatsPresentation {
    static func points(from buckets: [AlertBucket]) -> [AlertBucket] {
        buckets.filter { $0.count > 0 }
    }

    static func maxCount(from buckets: [AlertBucket]) -> Int {
        max(1, buckets.map(\.count).max() ?? 1)
    }
}
