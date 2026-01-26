import AppKit
import Combine
import Foundation

final class AppState: ObservableObject {
    @Published private(set) var isMonitoring = false
    @Published var lastError: DetectionStartError?

    let settings: SettingsStore
    let stats: StatsStore
    let cameraStore: CameraStore

    private let alertManager: AlertManager
    private let detectionEngine: DetectionEngine
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let settings = SettingsStore()
        let stats = StatsStore()
        let cameraStore = CameraStore()
        let alertManager = AlertManager()

        self.settings = settings
        self.stats = stats
        self.cameraStore = cameraStore
        self.alertManager = alertManager
        self.detectionEngine = DetectionEngine(
            settingsProvider: {
                DetectionSettings(
                    sensitivity: settings.sensitivity,
                    cooldownSeconds: settings.cooldownSeconds,
                    cameraID: settings.cameraID
                )
            },
            onTrigger: { [weak stats, weak alertManager, weak settings] in
                stats?.recordAlert()
                if let alertType = settings?.alertType {
                    alertManager?.trigger(alertType: alertType)
                }
            }
        )

        settings.$alertType
            .sink { [weak alertManager] alertType in
                if alertType.usesBanner {
                    alertManager?.ensureNotificationAuthorization()
                }
            }
            .store(in: &cancellables)

        cameraStore.$devices
            .sink { [weak self] _ in
                guard let self else { return }
                let preferred = self.cameraStore.preferredDeviceID(storedID: self.settings.cameraID)
                if preferred != self.settings.cameraID {
                    self.settings.cameraID = preferred
                }
            }
            .store(in: &cancellables)

        settings.$cameraID
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.isMonitoring else { return }
                self.restartMonitoring()
            }
            .store(in: &cancellables)

        if settings.cameraID == nil {
            settings.cameraID = cameraStore.preferredDeviceID(storedID: nil)
        }
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        lastError = nil
        detectionEngine.start { [weak self] error in
            guard let self else { return }
            if let error {
                self.isMonitoring = false
                self.lastError = error
                return
            }

            self.isMonitoring = true
            self.startMonitoringTimer()
        }
    }

    func stopMonitoring() {
        detectionEngine.stop()
        stopMonitoringTimer()
        isMonitoring = false
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func startMonitoringTimer() {
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.stats.addMonitoringSeconds(1)
        }
    }

    private func stopMonitoringTimer() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}
