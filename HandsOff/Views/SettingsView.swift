import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var cameraStore: CameraStore

    private let cooldownOptions: [Double] = [1, 2, 3, 5, 10, 15, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.subheadline)

            cameraPicker

            Picker("Sensitivity", selection: $settings.sensitivity) {
                ForEach(Sensitivity.allCases) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.menu)

            Picker("Alert", selection: $settings.alertType) {
                ForEach(AlertType.allCases) { alert in
                    Text(alert.label).tag(alert)
                }
            }
            .pickerStyle(.menu)

            Picker("Cooldown", selection: $settings.cooldownSeconds) {
                ForEach(cooldownOptions, id: \.self) { option in
                    Text("\(Int(option))s").tag(option)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var cameraPicker: some View {
        if cameraStore.devices.isEmpty {
            Text("Camera: none detected")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("Camera", selection: $settings.cameraID) {
                ForEach(cameraStore.devices, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(Optional(device.uniqueID))
                }
            }
            .pickerStyle(.menu)
        }
    }
}
