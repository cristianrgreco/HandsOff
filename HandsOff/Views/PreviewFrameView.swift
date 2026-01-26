import CoreGraphics
import SwiftUI

struct PreviewFrameView: View {
    let image: CGImage
    let faceZone: CGRect?
    let isHit: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = faceRect(for: faceZone, in: size)
            ZStack {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()

                DetectionOverlayView(faceRect: rect, isHit: isHit)
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
}
