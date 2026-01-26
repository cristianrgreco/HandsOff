import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let error = appState.lastError {
                Text(error.rawValue)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                if error == .permissionDenied {
                    Button("Open Camera Settings") {
                        appState.openCameraSettings()
                    }
                }
            }

            Button(appState.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                appState.toggleMonitoring()
            }

            Divider()
            StatsView(stats: appState.stats)
            Divider()
            SettingsView(settings: appState.settings, cameraStore: appState.cameraStore)
            Divider()

            Button("Quit Hands Off") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: appState.isMonitoring ? "hand.raised.fill" : "hand.raised")
            VStack(alignment: .leading, spacing: 2) {
                Text("Hands Off")
                    .font(.headline)
                Text(appState.isMonitoring ? "Monitoring on" : "Monitoring off")
                    .font(.caption)
                    .foregroundStyle(appState.isMonitoring ? .green : .secondary)
            }
        }
    }
}
