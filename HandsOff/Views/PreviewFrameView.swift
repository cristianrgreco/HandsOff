import CoreGraphics
import SwiftUI

struct PreviewFrameView: View {
    let image: CGImage
    let faceZone: CGRect?
    let isHit: Bool
    let handPoints: [CGPoint]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = faceRect(for: faceZone, in: size)
            let points = points(for: handPoints, in: size)
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()

                DetectionOverlayView(faceRect: rect, isHit: isHit, handPoints: points)
            }
        }
        .clipped()
    }

    private func faceRect(for faceZone: CGRect?, in size: CGSize) -> CGRect? {
        guard let faceZone else { return nil }
        let x = faceZone.origin.x * size.width
        let y = (1 - faceZone.origin.y - faceZone.height) * size.height
        return CGRect(
            x: x,
            y: y,
            width: faceZone.width * size.width,
            height: faceZone.height * size.height
        )
    }

    private func points(for normalizedPoints: [CGPoint], in size: CGSize) -> [CGPoint] {
        normalizedPoints.map { point in
            CGPoint(
                x: point.x * size.width,
                y: (1 - point.y) * size.height
            )
        }
    }
}
