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
            Toggle("Banner", isOn: $settings.alertBannerEnabled)
            Toggle("Blur screen", isOn: $settings.blurOnTouch)
            HStack {
                Text("Blur intensity")
                Slider(value: $settings.blurIntensity, in: 0.25...0.9, step: 0.05)
                Text("\(Int(settings.blurIntensity * 100))%")
                    .frame(minWidth: 40, alignment: .trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.blurOnTouch)

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
