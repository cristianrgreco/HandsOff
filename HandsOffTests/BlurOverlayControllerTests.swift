import XCTest
@testable import HandsOff

final class BlurOverlayControllerTests: XCTestCase {
    func testCreatesWindowPerScreen() {
        let controller = BlurOverlayController()

        XCTAssertEqual(controller._testWindowCount, NSScreen.screens.count)
    }

    func testRebuildWindowsUsesCurrentScreens() {
        let controller = BlurOverlayController()
        controller._testRebuildWindows()

        XCTAssertEqual(controller._testWindowCount, NSScreen.screens.count)
    }

    func testShowSetsVisibleAndAppliesFlashAlpha() {
        let controller = BlurOverlayController()

        controller.show()

        XCTAssertTrue(controller._testIsVisible)
        XCTAssertTrue(controller._testIsFlashOn)
        XCTAssertFalse(controller._testWindowAlphas.isEmpty)
        for alpha in controller._testWindowAlphas {
            XCTAssertEqual(alpha, controller._testFlashAlpha, accuracy: 0.001)
        }
    }

    func testHideClearsVisibilityAndResetsAlpha() {
        let controller = BlurOverlayController()

        controller.show()
        controller.hide()

        XCTAssertFalse(controller._testIsVisible)
        XCTAssertFalse(controller._testIsFlashOn)
        for alpha in controller._testWindowAlphas {
            XCTAssertEqual(alpha, 0.0, accuracy: 0.001)
        }
    }
}
