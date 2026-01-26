import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            card { previewSection }
            card { StatsView(stats: appState.stats) }
            card { SettingsView(settings: appState.settings, cameraStore: appState.cameraStore) }
        }
        .padding(12)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: appState.isMonitoring ? "hand.raised.fill" : "hand.raised")
            VStack(alignment: .leading, spacing: 2) {
                Text("Hands Off")
                    .font(.headline)
                    .fontDesign(.rounded)
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
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if appState.isMonitoring {
                if let previewImage = appState.previewImage {
                    PreviewFrameView(
                        image: previewImage,
                        faceZone: appState.previewFaceZone,
                        isHit: appState.previewHit
                    )
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.previewHit ? .red : .secondary, lineWidth: 2)
                        )
                } else {
                    previewPlaceholder(text: "Waiting for camera...")
                }
            } else {
                previewPlaceholder(text: "Start monitoring to show the camera feed.")
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

    private func previewPlaceholder(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                )
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
    }
}
