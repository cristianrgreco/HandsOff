import CoreGraphics

struct PreviewFrameGeometry {
    static func faceRect(
        for faceZone: CGRect?,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect? {
        guard let faceZone else { return nil }
        let scale = fillScale(imageSize: imageSize, viewSize: viewSize)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = fillOffset(scaledSize: scaledSize, viewSize: viewSize)

        let x = faceZone.origin.x * imageSize.width
        let y = (1 - faceZone.origin.y - faceZone.height) * imageSize.height
        let width = faceZone.width * imageSize.width
        let height = faceZone.height * imageSize.height

        return CGRect(
            x: x * scale - offset.x,
            y: y * scale - offset.y,
            width: width * scale,
            height: height * scale
        )
    }

    static func points(
        for normalizedPoints: [CGPoint],
        imageSize: CGSize,
        viewSize: CGSize
    ) -> [CGPoint] {
        let scale = fillScale(imageSize: imageSize, viewSize: viewSize)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = fillOffset(scaledSize: scaledSize, viewSize: viewSize)

        return normalizedPoints.map { point in
            let imageX = point.x * imageSize.width
            let imageY = (1 - point.y) * imageSize.height
            return CGPoint(
                x: imageX * scale - offset.x,
                y: imageY * scale - offset.y
            )
        }
    }

    private static func fillScale(imageSize: CGSize, viewSize: CGSize) -> CGFloat {
        let widthScale = viewSize.width / max(1, imageSize.width)
        let heightScale = viewSize.height / max(1, imageSize.height)
        return max(widthScale, heightScale)
    }

    private static func fillOffset(scaledSize: CGSize, viewSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, (scaledSize.width - viewSize.width) / 2),
            y: max(0, (scaledSize.height - viewSize.height) / 2)
        )
    }
}
