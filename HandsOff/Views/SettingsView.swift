import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var cameraStore: AnyCameraStore

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
        if let placeholder = SettingsPresentation.cameraPlaceholderText(devices: cameraStore.devices) {
            Text(placeholder)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("camera-placeholder")
        } else {
            Picker("Camera", selection: $settings.cameraID) {
                ForEach(cameraStore.devices, id: \.id) { device in
                    Text(device.name).tag(Optional(device.id))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("camera-picker")
        }
    }

    private var faceZoneScaleLabel: String {
        "\(Int((settings.faceZoneScale * 100).rounded()))%"
    }
}
