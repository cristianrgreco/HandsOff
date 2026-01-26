import Combine
import CoreGraphics
import Foundation

enum Sensitivity: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var zoneExpansion: CGFloat {
        switch self {
        case .low: return 0.12
        case .medium: return 0.20
        case .high: return 0.28
        }
    }

    var debounceWindow: Int {
        switch self {
        case .low: return 5
        case .medium: return 3
        case .high: return 2
        }
    }

    var hitThreshold: Int {
        switch self {
        case .low: return 3
        case .medium: return 2
        case .high: return 1
        }
    }
}

enum AlertType: String, CaseIterable, Identifiable {
    case chime
    case banner
    case both
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chime: return "Sound"
        case .banner: return "Banner"
        case .both: return "Both"
        case .off: return "Off"
        }
    }

    var usesBanner: Bool {
        self == .banner || self == .both
    }
}

enum AlertSound: String, CaseIterable, Identifiable {
    case softTick = "soft_tick"
    case ping = "ping"
    case strongBeep = "strong_beep"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .softTick: return "Soft Tick"
        case .ping: return "Ping"
        case .strongBeep: return "Strong Beep"
        }
    }

    var systemSoundName: String {
        switch self {
        case .softTick: return "Tink"
        case .ping: return "Ping"
        case .strongBeep: return "Basso"
        }
    }
}

final class SettingsStore: ObservableObject {
    @Published var sensitivity: Sensitivity { didSet { save() } }
    @Published var alertType: AlertType { didSet { save() } }
    @Published var alertSound: AlertSound { didSet { save() } }
    @Published var cooldownSeconds: Double { didSet { save() } }
    @Published var cameraID: String? { didSet { save() } }
    @Published var blurOnTouch: Bool { didSet { save() } }
    @Published var blurIntensity: Double { didSet { save() } }
    @Published var startAtLogin: Bool { didSet { save() } }
    @Published var resumeMonitoringOnLaunch: Bool { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.sensitivity) != nil {
            let sensitivityRaw = defaults.integer(forKey: Keys.sensitivity)
            self.sensitivity = Sensitivity(rawValue: sensitivityRaw) ?? .medium
        } else {
            self.sensitivity = .medium
        }

        let alertRaw = defaults.string(forKey: Keys.alertType) ?? AlertType.chime.rawValue
        self.alertType = AlertType(rawValue: alertRaw) ?? .chime

        let soundRaw = defaults.string(forKey: Keys.alertSound) ?? AlertSound.ping.rawValue
        self.alertSound = AlertSound(rawValue: soundRaw) ?? .ping

        let cooldownValue = defaults.double(forKey: Keys.cooldownSeconds)
        self.cooldownSeconds = cooldownValue > 0 ? cooldownValue : 10

        self.cameraID = defaults.string(forKey: Keys.cameraID)
        self.blurOnTouch = defaults.bool(forKey: Keys.blurOnTouch)
        if defaults.object(forKey: Keys.blurIntensity) != nil {
            self.blurIntensity = defaults.double(forKey: Keys.blurIntensity)
        } else {
            self.blurIntensity = 0.75
        }
        self.startAtLogin = defaults.bool(forKey: Keys.startAtLogin)
        self.resumeMonitoringOnLaunch = defaults.bool(forKey: Keys.resumeMonitoringOnLaunch)
    }

    private func save() {
        defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity)
        defaults.set(alertType.rawValue, forKey: Keys.alertType)
        defaults.set(alertSound.rawValue, forKey: Keys.alertSound)
        defaults.set(cooldownSeconds, forKey: Keys.cooldownSeconds)
        defaults.set(cameraID, forKey: Keys.cameraID)
        defaults.set(blurOnTouch, forKey: Keys.blurOnTouch)
        defaults.set(blurIntensity, forKey: Keys.blurIntensity)
        defaults.set(startAtLogin, forKey: Keys.startAtLogin)
        defaults.set(resumeMonitoringOnLaunch, forKey: Keys.resumeMonitoringOnLaunch)
    }

    private enum Keys {
        static let sensitivity = "settings.sensitivity"
        static let alertType = "settings.alertType"
        static let alertSound = "settings.alertSound"
        static let cooldownSeconds = "settings.cooldownSeconds"
        static let cameraID = "settings.cameraID"
        static let blurOnTouch = "settings.blurOnTouch"
        static let blurIntensity = "settings.blurIntensity"
        static let startAtLogin = "settings.startAtLogin"
        static let resumeMonitoringOnLaunch = "settings.resumeMonitoringOnLaunch"
    }
}
