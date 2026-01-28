import UserNotifications
import XCTest
@testable import HandsOff

final class AlertManagerTests: XCTestCase {
    func testEnsureNotificationAuthorizationRequestsWhenNotDetermined() {
        let center = FakeNotificationCenter(status: .notDetermined)
        let manager = AlertManager(notificationCenter: center, tonePlayer: FakeTonePlayer())

        manager.ensureNotificationAuthorization()

        XCTAssertEqual(center.requestAuthorizationCount, 1)
        XCTAssertEqual(center.requestedOptions, [.alert, .sound])
    }

    func testEnsureNotificationAuthorizationDoesNotRequestWhenAuthorized() {
        let center = FakeNotificationCenter(status: .authorized)
        let manager = AlertManager(notificationCenter: center, tonePlayer: FakeTonePlayer())

        manager.ensureNotificationAuthorization()

        XCTAssertEqual(center.requestAuthorizationCount, 0)
    }

    func testToneLifecycleForwarding() {
        let tonePlayer = FakeTonePlayer()
        let manager = AlertManager(notificationCenter: FakeNotificationCenter(status: .authorized), tonePlayer: tonePlayer)

        manager.prepareContinuous()
        manager.startContinuous()
        manager.stopContinuous()
        manager.shutdownContinuous()

        XCTAssertEqual(tonePlayer.prepareCount, 1)
        XCTAssertEqual(tonePlayer.startCount, 1)
        XCTAssertEqual(tonePlayer.stopCount, 1)
        XCTAssertEqual(tonePlayer.shutdownCount, 1)
    }

    func testPostBannerEnqueuesNotification() {
        let center = FakeNotificationCenter(status: .authorized)
        let manager = AlertManager(notificationCenter: center, tonePlayer: FakeTonePlayer())

        manager.postBanner()

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = center.addedRequests.first
        XCTAssertEqual(request?.content.title, "Hands Off")
        XCTAssertEqual(request?.content.body, "Hands near face.")
        XCTAssertNil(request?.content.sound)
        XCTAssertFalse(request?.identifier.isEmpty ?? true)
    }
}

private final class FakeNotificationSettings: NotificationSettingsType {
    let authorizationStatus: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        authorizationStatus = status
    }
}

private final class FakeNotificationCenter: NotificationCenterType {
    private let settings: NotificationSettingsType
    private(set) var requestAuthorizationCount = 0
    private(set) var requestedOptions: UNAuthorizationOptions?
    private(set) var addedRequests: [UNNotificationRequest] = []

    init(status: UNAuthorizationStatus) {
        settings = FakeNotificationSettings(status: status)
    }

    func getNotificationSettings(completion: @escaping (NotificationSettingsType) -> Void) {
        completion(settings)
    }

    func requestAuthorization(options: UNAuthorizationOptions, completion: @escaping (Bool, Error?) -> Void) {
        requestAuthorizationCount += 1
        requestedOptions = options
        completion(true, nil)
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completion: ((Error?) -> Void)?) {
        addedRequests.append(request)
        completion?(nil)
    }
}

private final class FakeTonePlayer: TonePlaying {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var prepareCount = 0
    private(set) var shutdownCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func prepare() {
        prepareCount += 1
    }

    func shutdown() {
        shutdownCount += 1
    }
}
