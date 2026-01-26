import SwiftUI

struct DetectionOverlayView: View {
    let faceRect: CGRect?
    let isHit: Bool

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if let faceRect {
                    Rectangle()
                        .stroke(isHit ? Color.red : Color.yellow, lineWidth: 2)
                        .background(Color.clear)
                        .frame(width: faceRect.width, height: faceRect.height)
                        .position(x: faceRect.midX, y: faceRect.midY)
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
}
