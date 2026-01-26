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
        case .chime: return "Chime"
        case .banner: return "Banner"
        case .both: return "Both"
        case .off: return "Off"
        }
    }

    var usesBanner: Bool {
        self == .banner || self == .both
    }
}

final class SettingsStore: ObservableObject {
    @Published var sensitivity: Sensitivity { didSet { save() } }
    @Published var alertType: AlertType { didSet { save() } }
    @Published var cooldownSeconds: Double { didSet { save() } }
    @Published var cameraID: String? { didSet { save() } }
    @Published var blurOnTouch: Bool { didSet { save() } }

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

        let cooldownValue = defaults.double(forKey: Keys.cooldownSeconds)
        self.cooldownSeconds = cooldownValue > 0 ? cooldownValue : 10

        self.cameraID = defaults.string(forKey: Keys.cameraID)
        self.blurOnTouch = defaults.bool(forKey: Keys.blurOnTouch)
    }

    private func save() {
        defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity)
        defaults.set(alertType.rawValue, forKey: Keys.alertType)
        defaults.set(cooldownSeconds, forKey: Keys.cooldownSeconds)
        defaults.set(cameraID, forKey: Keys.cameraID)
        defaults.set(blurOnTouch, forKey: Keys.blurOnTouch)
    }

    private enum Keys {
        static let sensitivity = "settings.sensitivity"
        static let alertType = "settings.alertType"
        static let cooldownSeconds = "settings.cooldownSeconds"
        static let cameraID = "settings.cameraID"
        static let blurOnTouch = "settings.blurOnTouch"
    }
}
