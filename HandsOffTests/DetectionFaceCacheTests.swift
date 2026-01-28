import CoreGraphics
import XCTest
@testable import HandsOff

final class DetectionFaceCacheTests: XCTestCase {
    func testResolveUsesNewFaceBoxWhenAvailable() {
        let faceBox = CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)

        let result = DetectionFaceCache.resolve(
            faceBox: faceBox,
            handPoints: [],
            now: 1.0,
            faceZoneScale: 1.0,
            lastFaceBox: nil,
            lastFaceTime: 0,
            sensitivityExpansion: 0,
            hairTopMargin: 0,
            faceCacheDuration: 2.0
        )

        XCTAssertEqual(result.faceBox, faceBox)
        XCTAssertEqual(result.lastFaceBox, faceBox)
        XCTAssertEqual(result.lastFaceTime, 1.0, accuracy: 0.0001)
    }

    func testResolveKeepsCachedFaceWhenHandOverlapsZone() {
        let cached = CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)
        let handPoint = CGPoint(x: 0.25, y: 0.25)

        let result = DetectionFaceCache.resolve(
            faceBox: nil,
            handPoints: [handPoint],
            now: 5.0,
            faceZoneScale: 1.0,
            lastFaceBox: cached,
            lastFaceTime: 1.0,
            sensitivityExpansion: 0,
            hairTopMargin: 0,
            faceCacheDuration: 2.0
        )

        XCTAssertEqual(result.faceBox, cached)
        XCTAssertEqual(result.lastFaceTime, 5.0, accuracy: 0.0001)
    }

    func testResolveKeepsCachedFaceWithinCacheWindow() {
        let cached = CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)

        let result = DetectionFaceCache.resolve(
            faceBox: nil,
            handPoints: [],
            now: 2.0,
            faceZoneScale: 1.0,
            lastFaceBox: cached,
            lastFaceTime: 1.0,
            sensitivityExpansion: 0,
            hairTopMargin: 0,
            faceCacheDuration: 2.0
        )

        XCTAssertEqual(result.faceBox, cached)
        XCTAssertEqual(result.lastFaceTime, 1.0, accuracy: 0.0001)
    }

    func testResolveDropsCachedFaceAfterTimeout() {
        let cached = CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2)

        let result = DetectionFaceCache.resolve(
            faceBox: nil,
            handPoints: [],
            now: 5.0,
            faceZoneScale: 1.0,
            lastFaceBox: cached,
            lastFaceTime: 1.0,
            sensitivityExpansion: 0,
            hairTopMargin: 0,
            faceCacheDuration: 2.0
        )

        XCTAssertNil(result.faceBox)
    }
}
