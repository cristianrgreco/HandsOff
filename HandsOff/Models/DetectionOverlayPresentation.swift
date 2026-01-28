import CoreGraphics
import Foundation

enum OverlayTone: Equatable {
    case accent
    case alert
}

struct DetectionOverlayPresentation {
    static func showsAlert(isHit: Bool) -> Bool {
        isHit
    }

    static func pointTone(faceRect: CGRect?, point: CGPoint) -> OverlayTone {
        if let faceRect, faceRect.contains(point) {
            return .alert
        }
        return .accent
    }
}
