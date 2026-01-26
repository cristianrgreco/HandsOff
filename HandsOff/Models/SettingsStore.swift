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

    var usesSound: Bool {
        self == .chime || self == .both
    }
}

final class SettingsStore: ObservableObject {
    @Published var alertType: AlertType { didSet { save() } }
    @Published var cameraID: String? { didSet { save() } }
    @Published var blurOnTouch: Bool { didSet { save() } }
    @Published var blurIntensity: Double { didSet { save() } }
    @Published var startAtLogin: Bool { didSet { save() } }
    @Published var resumeMonitoringOnLaunch: Bool { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let alertRaw = defaults.string(forKey: Keys.alertType) ?? AlertType.chime.rawValue
        self.alertType = AlertType(rawValue: alertRaw) ?? .chime

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
        defaults.set(alertType.rawValue, forKey: Keys.alertType)
        defaults.set(cameraID, forKey: Keys.cameraID)
        defaults.set(blurOnTouch, forKey: Keys.blurOnTouch)
        defaults.set(blurIntensity, forKey: Keys.blurIntensity)
        defaults.set(startAtLogin, forKey: Keys.startAtLogin)
        defaults.set(resumeMonitoringOnLaunch, forKey: Keys.resumeMonitoringOnLaunch)
    }

    private enum Keys {
        static let alertType = "settings.alertType"
        static let cameraID = "settings.cameraID"
        static let blurOnTouch = "settings.blurOnTouch"
        static let blurIntensity = "settings.blurIntensity"
        static let startAtLogin = "settings.startAtLogin"
        static let resumeMonitoringOnLaunch = "settings.resumeMonitoringOnLaunch"
    }
}
