import Charts
import SwiftUI

struct StatsView: View {
    @ObservedObject var stats: StatsStore
    @State private var range: AlertRange = .hour

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stats")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack {
                Text("Today")
                Spacer()
                Text("\(stats.alertsToday)")
                    .font(.title3)
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Picker("Range", selection: $range) {
                    ForEach(AlertRange.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()

                Button {
                    stats.resetAll()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .accessibilityLabel("Reset stats")
                }
                .buttonStyle(.bordered)
                .help("Reset stats")
            }

            TimelineView(.periodic(from: .now, by: range.refreshInterval)) { context in
                let buckets = stats.alertBuckets(for: range, now: context.date)
                let points = buckets.filter { $0.count > 0 }
                let maxCount = max(1, buckets.map(\.count).max() ?? 1)

                Chart(points) { bucket in
                    PointMark(
                        x: .value("Time", bucket.date),
                        y: .value("Touches", bucket.count)
                    )
                .symbolSize(20)
            }
            .chartYScale(domain: 0...maxCount)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
                .frame(height: 120)
            }
            .padding(4)
        }
    }
}
