import SwiftUI

struct ChapterSwipeIndicator: View {
    let title: String
    let edge: Edge
    let progress: CGFloat

    var body: some View {
        HStack(spacing: MonoriSpacing.x1) {
            if edge == .top {
                Image(systemName: "chevron.up")
                Text(title).lineLimit(1)
            } else {
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down")
            }
        }
        .font(MonoriTypography.ui(12, relativeTo: .caption, weight: .medium))
        .tracking(MonoriTypography.uiTracking)
        .foregroundStyle(MonoriPalette.ink)
        .padding(.horizontal, MonoriSpacing.x2)
        .padding(.vertical, MonoriSpacing.x1)
        .background(MonoriPalette.surface, in: RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                .stroke(MonoriPalette.divider, lineWidth: 1)
        }
        .opacity(Double(progress))
        .scaleEffect(0.8 + 0.2 * progress)
        .allowsHitTesting(false)
    }
}
