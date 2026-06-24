import SwiftUI

struct ChapterSwipeIndicator: View {
    let title: String
    let edge: Edge
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            if edge == .top {
                Image(systemName: "chevron.up")
                Text(title).lineLimit(1)
            } else {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down")
            }
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(Double(progress))
        .scaleEffect(0.8 + 0.2 * progress)
        .allowsHitTesting(false)
    }
}
