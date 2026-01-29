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
            let imageSize = CGSize(width: image.width, height: image.height)
            let rect = PreviewFrameGeometry.faceRect(
                for: faceZone,
                imageSize: imageSize,
                viewSize: size
            )
            let points = PreviewFrameGeometry.points(
                for: handPoints,
                imageSize: imageSize,
                viewSize: size
            )
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()

                DetectionOverlayView(faceRect: rect, isHit: isHit, handPoints: points)
            }
        }
        .clipped()
    }
}
