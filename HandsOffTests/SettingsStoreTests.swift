import XCTest
@testable import HandsOff

final class SettingsStoreTests: XCTestCase {
    func testLegacyAlertTypeAndBlurMigrations() {
        let defaults = makeDefaults()
        defaults.set("both", forKey: "settings.alertType")
        defaults.set(false, forKey: "settings.blurOnTouch")

        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.alertSoundEnabled)
        XCTAssertTrue(store.alertBannerEnabled)
        XCTAssertFalse(store.flashScreenOnTouch)
        XCTAssertNil(defaults.object(forKey: "settings.blurOnTouch"))
    }

    func testFaceZoneScaleMigrationClampsLegacyValues() {
        let defaults = makeDefaults()
        let baseline = SettingsStore.faceZoneBaselineScale
        defaults.set(baseline * 3.0, forKey: "settings.faceZoneScale")
        defaults.set(1, forKey: "settings.faceZoneScaleVersion")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.faceZoneScale, SettingsStore.faceZoneScaleRange.upperBound)
    }

    func testExplicitAlertSettingsOverrideLegacyAlertType() {
        let defaults = makeDefaults()
        defaults.set("both", forKey: "settings.alertType")
        defaults.set(false, forKey: "settings.alertSoundEnabled")
        defaults.set(false, forKey: "settings.alertBannerEnabled")

        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.alertSoundEnabled)
        XCTAssertFalse(store.alertBannerEnabled)
    }

    func testDefaultFlashScreenOnTouchIsEnabled() {
        let defaults = makeDefaults()

        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.flashScreenOnTouch)
    }

    func testDefaultAlertSettings() {
        let defaults = makeDefaults()

        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.alertSoundEnabled)
        XCTAssertFalse(store.alertBannerEnabled)
    }

    func testFaceZoneScaleClampsWhenCurrentVersionStored() {
        let defaults = makeDefaults()
        defaults.set(-1.0, forKey: "settings.faceZoneScale")
        defaults.set(2, forKey: "settings.faceZoneScaleVersion")

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.faceZoneScale, SettingsStore.faceZoneScaleRange.lowerBound)
    }

    func testFaceZoneScaleVersionPersistsOnInit() {
        let defaults = makeDefaults()

        _ = SettingsStore(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: "settings.faceZoneScaleVersion"), 2)
    }

    func testDefaultsPersistWhenSettingChanges() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.alertSoundEnabled = false

        XCTAssertFalse(defaults.bool(forKey: "settings.alertSoundEnabled"))
    }

    func testStartAtLoginDefaultsToFalse() {
        let defaults = makeDefaults()

        let store = SettingsStore(defaults: defaults)

        XCTAssertFalse(store.startAtLogin)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "HandsOffTests.SettingsStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
