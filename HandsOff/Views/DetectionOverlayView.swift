import SwiftUI

struct DetectionOverlayView: View {
    let faceRect: CGRect?
    let isHit: Bool
    let handPoints: [CGPoint]

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if let faceRect {
                    Rectangle()
                        .stroke(isHit ? Color.red : accentColor, lineWidth: 2)
                        .background(Color.clear)
                        .frame(width: faceRect.width, height: faceRect.height)
                        .position(x: faceRect.midX, y: faceRect.midY)
                }

                ForEach(handPoints.indices, id: \.self) { index in
                    let point = handPoints[index]
                    Circle()
                        .fill(color(for: point))
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.7), lineWidth: 1)
                        )
                        .position(x: point.x, y: point.y)
                }

                if isHit {
                    Text("ALERT")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var accentColor: Color {
        #if os(macOS)
        let color = NSColor.controlAccentColor
        if color == .clear {
            return .yellow
        }
        return Color(color)
        #else
        return .yellow
        #endif
    }

    private func color(for point: CGPoint) -> Color {
        if let faceRect, faceRect.contains(point) {
            return .red
        }
        return accentColor
    }
}
