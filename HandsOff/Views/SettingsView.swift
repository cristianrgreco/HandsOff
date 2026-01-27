import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var cameraStore: CameraStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            sectionHeader("System")
            Toggle("Start at login", isOn: $settings.startAtLogin)

            sectionHeader("Camera")
            cameraPicker

            sectionHeader("Detection")
            HStack {
                Text("Area size")
                Spacer()
                Text(faceZoneScaleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.faceZoneScale, in: SettingsStore.faceZoneScaleRange, step: 0.01)

            sectionHeader("Alerts")
            Toggle("Sound", isOn: $settings.alertSoundEnabled)
            Toggle("Flash screen", isOn: $settings.flashScreenOnTouch)
            Toggle("Notification banner", isOn: $settings.alertBannerEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
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

    private var faceZoneScaleLabel: String {
        "\(Int((settings.faceZoneScale * 100).rounded()))%"
    }
}
