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

            sectionHeader("Camera")
            cameraPicker

            sectionHeader("Alerts")
            Toggle("Sound", isOn: $settings.alertSoundEnabled)
            Toggle("Flash screen", isOn: $settings.flashScreenOnTouch)
            Toggle("Notification banner", isOn: $settings.alertBannerEnabled)

            sectionHeader("System")
            Toggle("Start at login", isOn: $settings.startAtLogin)
        }
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
}
