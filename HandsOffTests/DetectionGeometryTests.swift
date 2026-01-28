import CoreGraphics
import XCTest
@testable import HandsOff

final class DetectionGeometryTests: XCTestCase {
    func testExpandedRectClampsToUnitBounds() {
        let rect = CGRect(x: 0.9, y: 0.9, width: 0.2, height: 0.2)
        let expanded = DetectionGeometry.expandedRect(rect, by: 0.5)

        XCTAssertGreaterThanOrEqual(expanded.minX, 0)
        XCTAssertGreaterThanOrEqual(expanded.minY, 0)
        XCTAssertLessThanOrEqual(expanded.maxX, 1)
        XCTAssertLessThanOrEqual(expanded.maxY, 1)
    }

    func testScaledRectKeepsCenter() {
        let rect = CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.2)
        let scaled = DetectionGeometry.scaledRect(rect, scale: 0.5)

        XCTAssertEqual(scaled.midX, rect.midX, accuracy: 0.0001)
        XCTAssertEqual(scaled.midY, rect.midY, accuracy: 0.0001)
    }

    func testFaceZoneAddsHairMargin() {
        let faceBox = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        let zone = DetectionGeometry.faceZone(
            faceBox: faceBox,
            scale: 1.0,
            sensitivityExpansion: 0,
            hairTopMargin: 0.25
        )

        XCTAssertGreaterThan(zone.height, faceBox.height)
    }

    func testFaceZoneRespectsScaleWithoutExpansion() {
        let faceBox = CGRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
        let scaled = DetectionGeometry.scaledRect(faceBox, scale: 0.5)
        let zone = DetectionGeometry.faceZone(
            faceBox: faceBox,
            scale: 0.5,
            sensitivityExpansion: 0,
            hairTopMargin: 0
        )

        XCTAssertEqual(zone.origin.x, scaled.origin.x, accuracy: 0.0001)
        XCTAssertEqual(zone.origin.y, scaled.origin.y, accuracy: 0.0001)
        XCTAssertEqual(zone.size.width, scaled.size.width, accuracy: 0.0001)
        XCTAssertEqual(zone.size.height, scaled.size.height, accuracy: 0.0001)
    }
}
