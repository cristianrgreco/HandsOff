import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var cameraStore: CameraStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            cameraPicker

            Picker("Alert", selection: $settings.alertType) {
                ForEach(AlertType.allCases) { alert in
                    Text(alert.label).tag(alert)
                }
            }
            .pickerStyle(.menu)

            Toggle("Blur screen on touch", isOn: $settings.blurOnTouch)
            HStack {
                Text("Blur intensity")
                Slider(value: $settings.blurIntensity, in: 0.25...0.9, step: 0.05)
                Text("\(Int(settings.blurIntensity * 100))%")
                    .frame(minWidth: 40, alignment: .trailing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.blurOnTouch)

            Toggle("Start at login", isOn: $settings.startAtLogin)
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
