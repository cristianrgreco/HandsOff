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

            previewSection

            Divider()
            StatsView(stats: appState.stats)
            Divider()
            SettingsView(settings: appState.settings, cameraStore: appState.cameraStore)
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
            Spacer()
            if appState.isMonitoring {
                Button {
                    appState.toggleMonitoring()
                } label: {
                    Text("Stop")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .help("Stop monitoring")
            } else {
                Button {
                    appState.toggleMonitoring()
                } label: {
                    Text("Start")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)
                .help("Start monitoring")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Quit Hands Off")
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.subheadline)

            if appState.isMonitoring {
                if let previewImage = appState.previewImage {
                    PreviewFrameView(
                        image: previewImage,
                        faceZone: appState.previewFaceZone,
                        isHit: appState.previewHit
                    )
                        .frame(width: 260, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.previewHit ? .red : .secondary, lineWidth: 2)
                        )
                } else {
                    Text("Waiting for camera...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Start monitoring to show the camera feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            appState.setPreviewEnabled(appState.isMonitoring)
        }
        .onChange(of: appState.isMonitoring) { isMonitoring in
            appState.setPreviewEnabled(isMonitoring)
        }
        .onDisappear {
            appState.setPreviewEnabled(false)
        }
    }
}
