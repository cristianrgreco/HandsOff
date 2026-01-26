import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var cameraStore: CameraStore

    private let cooldownOptions: [(label: String, value: Double)] = [
        ("Fast", 0.25),
        ("Regular", 1.0),
        ("Slow", 3.0)
    ]

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

            Picker("Sound", selection: $settings.alertSound) {
                ForEach(AlertSound.allCases) { sound in
                    Text(sound.label).tag(sound)
                }
            }
            .pickerStyle(.menu)
            .disabled(!settings.alertType.usesSound)

            Picker("Sound mode", selection: $settings.soundMode) {
                ForEach(SoundMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .disabled(!settings.alertType.usesSound)

            Picker("Cooldown", selection: $settings.cooldownSeconds) {
                ForEach(cooldownOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
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
