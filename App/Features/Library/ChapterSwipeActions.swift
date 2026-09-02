import SwiftUI

// MARK: - Trash Icon

/// Trash icon from user-provided SVG (viewBox 0 0 24 24, stroke-based).
struct SwipeTrashIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let ox = (rect.width - s) / 2
        let oy = (rect.height - s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x / 24 * s, y: oy + y / 24 * s)
        }
        var path = Path()
        path.move(to: p(3, 6)); path.addLine(to: p(21, 6))
        path.move(to: p(9, 6)); path.addLine(to: p(9, 4))
        path.addQuadCurve(to: p(11, 2), control: p(9, 2))
        path.addLine(to: p(13, 2))
        path.addQuadCurve(to: p(15, 4), control: p(15, 2))
        path.addLine(to: p(15, 6))
        path.move(to: p(19, 6)); path.addLine(to: p(19, 20))
        path.addQuadCurve(to: p(17, 22), control: p(19, 22))
        path.addLine(to: p(7, 22))
        path.addQuadCurve(to: p(5, 20), control: p(5, 22))
        path.addLine(to: p(5, 6))
        path.move(to: p(10, 11)); path.addLine(to: p(10, 17))
        path.move(to: p(14, 11)); path.addLine(to: p(14, 17))
        return path
    }
}

// MARK: - Swipe Modifier

struct ChapterSwipeModifier<ID: Equatable>: ViewModifier {
    @Environment(\.monoriUIMetrics) private var metrics
    let onDelete: () -> Void
    let onRename: (() -> Void)?
    @Binding var revealedID: ID?
    let itemID: ID

    @State private var offset: CGFloat = 0

    private var buttonWidth: CGFloat { metrics.isRegularWidth ? 88 : 72 }
    private var totalReveal: CGFloat { onRename != nil ? buttonWidth * 2 : buttonWidth }

    /// Fixed light foreground for action labels.
    /// MonoriBookmark (#A64D4D) has no dark variant; adaptive MonoriCanvas
    /// flips to near-black in dark mode (3.4:1 — fails WCAG AA).
    /// This equals MonoriCanvas light-mode (#FBF9F8).
    private static var buttonLabel: Color {
        Color(red: 0.984, green: 0.976, blue: 0.973)
    }

    private var isRevealed: Bool { offset < -1 }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            actionButtons

            content
                .background(MonoriPalette.canvas)
                .offset(x: offset)
                .allowsHitTesting(!isRevealed)
        }
        .clipped()
        .overlay {
            if isRevealed {
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissSwipe() }
                    Color.clear
                        .frame(width: totalReveal)
                        .allowsHitTesting(false)
                }
            }
        }
        .simultaneousGesture(swipeGesture)
        .onChange(of: revealedID) { _, newValue in
            guard newValue != itemID, offset != 0 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                offset = 0
            }
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 0) {
            if let onRename {
                Button {
                    dismissSwipe()
                    DispatchQueue.main.async { onRename() }
                } label: {
                    Text("重新命名")
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize, weight: .medium))
                        .foregroundStyle(Self.buttonLabel)
                        .frame(width: buttonWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.420, green: 0.408, blue: 0.388))
                }
                .buttonStyle(.plain)
            }

            Button {
                dismissSwipe()
                DispatchQueue.main.async { onDelete() }
            } label: {
                VStack(spacing: 4) {
                    SwipeTrashIcon()
                        .stroke(Self.buttonLabel,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .frame(width: metrics.actionIconSize, height: metrics.actionIconSize)
                    Text("刪除")
                        .font(MonoriTypography.ui(metrics.buttonLabelFontSize, weight: .medium))
                }
                .foregroundStyle(Self.buttonLabel)
                .frame(width: buttonWidth)
                .frame(maxHeight: .infinity)
                .background(MonoriPalette.bookmark)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) else { return }
                let base: CGFloat = revealedID == itemID ? -totalReveal : 0
                let proposed = base + dx
                offset = max(-totalReveal * 1.1, min(0, proposed))
            }
            .onEnded { value in
                let base: CGFloat = revealedID == itemID ? -totalReveal : 0
                let projected = base + value.predictedEndTranslation.width
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    if projected < -totalReveal / 2 {
                        offset = -totalReveal
                        revealedID = itemID
                    } else {
                        offset = 0
                        if revealedID == itemID { revealedID = nil }
                    }
                }
            }
    }

    private func dismissSwipe() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            offset = 0
            revealedID = nil
        }
    }
}

// MARK: - View Extension

extension View {
    func chapterSwipeActions<ID: Equatable>(
        itemID: ID,
        revealedID: Binding<ID?>,
        onDelete: @escaping () -> Void,
        onRename: (() -> Void)? = nil
    ) -> some View {
        modifier(ChapterSwipeModifier(
            onDelete: onDelete,
            onRename: onRename,
            revealedID: revealedID,
            itemID: itemID
        ))
    }
}
