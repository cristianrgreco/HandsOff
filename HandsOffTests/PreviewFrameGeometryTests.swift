import CoreGraphics
import XCTest
@testable import HandsOff

final class PreviewFrameGeometryTests: XCTestCase {
    func testPointsMapCenterForFillCrop() {
        let imageSize = CGSize(width: 400, height: 200)
        let viewSize = CGSize(width: 200, height: 200)

        let points = PreviewFrameGeometry.points(
            for: [CGPoint(x: 0.5, y: 0.5)],
            imageSize: imageSize,
            viewSize: viewSize
        )

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].x, 100, accuracy: 0.001)
        XCTAssertEqual(points[0].y, 100, accuracy: 0.001)
    }

    func testFaceRectMapsWithFillCrop() {
        let imageSize = CGSize(width: 400, height: 200)
        let viewSize = CGSize(width: 200, height: 200)
        let faceZone = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

        let rect = PreviewFrameGeometry.faceRect(
            for: faceZone,
            imageSize: imageSize,
            viewSize: viewSize
        )

        XCTAssertNotNil(rect)
        XCTAssertEqual(rect?.origin.x ?? 0, 0, accuracy: 0.001)
        XCTAssertEqual(rect?.origin.y ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(rect?.size.width ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(rect?.size.height ?? 0, 100, accuracy: 0.001)
    }
}
