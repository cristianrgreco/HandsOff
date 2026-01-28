import XCTest
@testable import HandsOff

final class AppStateDependenciesTests: XCTestCase {
    func testActivityControllerLiveBeginEnd() {
        let controller = ActivityController.live
        let token = controller.begin("HandsOffTests")
        controller.end(token)
    }

    func testTimerDriverLiveMakeRepeatingFiresHandler() {
        let driver = TimerDriver.live
        let fireExpectation = expectation(description: "timer fired")
        let timer = driver.makeRepeating(0.1) {
            fireExpectation.fulfill()
        }

        timer.fire()
        wait(for: [fireExpectation], timeout: 1.0)
        timer.invalidate()
    }

    func testTimerDriverLiveMakeOneShotAndSchedule() {
        let driver = TimerDriver.live
        let fireExpectation = expectation(description: "one shot fired")
        let timer = driver.makeOneShot(Date()) {
            fireExpectation.fulfill()
        }

        driver.schedule(timer)
        timer.fire()
        wait(for: [fireExpectation], timeout: 1.0)
        timer.invalidate()
    }
}
