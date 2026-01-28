import CoreGraphics
import XCTest
@testable import HandsOff

final class DetectionOverlayPresentationTests: XCTestCase {
    func testShowsAlertWhenHit() {
        XCTAssertTrue(DetectionOverlayPresentation.showsAlert(isHit: true))
        XCTAssertFalse(DetectionOverlayPresentation.showsAlert(isHit: false))
    }

    func testPointToneUsesAlertInsideFaceRect() {
        let faceRect = CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
        let pointInside = CGPoint(x: 0.25, y: 0.25)
        let pointOutside = CGPoint(x: 0.9, y: 0.9)

        XCTAssertEqual(DetectionOverlayPresentation.pointTone(faceRect: faceRect, point: pointInside), .alert)
        XCTAssertEqual(DetectionOverlayPresentation.pointTone(faceRect: faceRect, point: pointOutside), .accent)
    }

    func testPointToneDefaultsToAccentWithoutFaceRect() {
        let point = CGPoint(x: 0.1, y: 0.1)

        XCTAssertEqual(DetectionOverlayPresentation.pointTone(faceRect: nil, point: point), .accent)
    }
}
