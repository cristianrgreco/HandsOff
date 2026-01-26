import SwiftUI

struct StatsView: View {
    @ObservedObject var stats: StatsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.subheadline)

            HStack {
                Text("Alerts")
                Spacer()
                Text("\(stats.alertsToday)")
            }

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                HStack {
                    Text("Monitoring")
                    Spacer()
                    Text(stats.formattedMonitoringTime)
                }
            }

            HStack {
                Text("Touch-free streak")
                Spacer()
                Text("\(stats.touchFreeStreakDays) days")
            }
        }
    }
}
