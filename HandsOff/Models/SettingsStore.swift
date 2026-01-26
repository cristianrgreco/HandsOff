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
    @Published var alertSoundEnabled: Bool { didSet { save() } }
    @Published var alertBannerEnabled: Bool { didSet { save() } }
    @Published var cameraID: String? { didSet { save() } }
    @Published var flashScreenOnTouch: Bool { didSet { save() } }
    @Published var startAtLogin: Bool { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let legacyAlertType = defaults.string(forKey: Keys.alertType).flatMap { AlertType(rawValue: $0) }
        if defaults.object(forKey: Keys.alertSoundEnabled) != nil {
            self.alertSoundEnabled = defaults.bool(forKey: Keys.alertSoundEnabled)
        } else if let legacyAlertType {
            self.alertSoundEnabled = legacyAlertType.usesSound
        } else {
            self.alertSoundEnabled = true
        }
        if defaults.object(forKey: Keys.alertBannerEnabled) != nil {
            self.alertBannerEnabled = defaults.bool(forKey: Keys.alertBannerEnabled)
        } else if let legacyAlertType {
            self.alertBannerEnabled = legacyAlertType.usesBanner
        } else {
            self.alertBannerEnabled = false
        }

        self.cameraID = defaults.string(forKey: Keys.cameraID)
        if defaults.object(forKey: Keys.flashScreenOnTouch) != nil {
            self.flashScreenOnTouch = defaults.bool(forKey: Keys.flashScreenOnTouch)
        } else if defaults.object(forKey: Keys.blurOnTouch) != nil {
            self.flashScreenOnTouch = defaults.bool(forKey: Keys.blurOnTouch)
            defaults.removeObject(forKey: Keys.blurOnTouch)
        } else {
            self.flashScreenOnTouch = true
        }
        self.startAtLogin = defaults.bool(forKey: Keys.startAtLogin)
    }

    private func save() {
        defaults.set(alertSoundEnabled, forKey: Keys.alertSoundEnabled)
        defaults.set(alertBannerEnabled, forKey: Keys.alertBannerEnabled)
        defaults.set(cameraID, forKey: Keys.cameraID)
        defaults.set(flashScreenOnTouch, forKey: Keys.flashScreenOnTouch)
        defaults.set(startAtLogin, forKey: Keys.startAtLogin)
    }

    private enum Keys {
        static let alertType = "settings.alertType"
        static let alertSoundEnabled = "settings.alertSoundEnabled"
        static let alertBannerEnabled = "settings.alertBannerEnabled"
        static let cameraID = "settings.cameraID"
        static let flashScreenOnTouch = "settings.flashScreenOnTouch"
        static let blurOnTouch = "settings.blurOnTouch"
        static let startAtLogin = "settings.startAtLogin"
    }
}
