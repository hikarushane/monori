import SwiftUI
import UIKit

/// A single-line title view that plays a one-shot horizontal scroll when the
/// text overflows its available width, then rests at the fully-scrolled
/// position. Short text that fits is left-aligned and never animates.
///
/// Designed for `ToolbarItem(placement: .principal)`. A hidden single-line
/// Text drives the layout so the toolbar allocates the correct width;
/// the visible fixed-size text is overlaid and scrolls when it overflows.
struct MarqueeText: View {
    let text: String
    var font: Font = .headline
    var speed: Double = 30
    var delayBeforeScroll: Double = 0.8

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    init(_ text: String, font: Font = .headline, speed: Double = 30, delayBeforeScroll: Double = 0.8) {
        self.text = text
        self.font = font
        self.speed = speed
        self.delayBeforeScroll = delayBeforeScroll
    }

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(.semibold)
            .lineLimit(1)
            .hidden()
            .overlay(alignment: .leading) {
                Text(text)
                    .font(font)
                    .fontWeight(.semibold)
                    .fixedSize()
                    .offset(x: offset)
            }
            .clipped()
            .background(GeometryReader { geo in
                Color.clear.preference(key: ContainerWidthKey.self, value: geo.size.width)
            })
            .onPreferenceChange(ContainerWidthKey.self) { containerWidth = $0 }
            .background(
                Text(text)
                    .font(font)
                    .fontWeight(.semibold)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: TextWidthKey.self, value: geo.size.width)
                    })
            )
            .onPreferenceChange(TextWidthKey.self) { textWidth = $0 }
            .task(id: text) {
                try? await Task.sleep(for: .milliseconds(100))
                guard textWidth > containerWidth, containerWidth > 0 else { return }
                try? await Task.sleep(for: .seconds(delayBeforeScroll))
                let overflow = textWidth - containerWidth
                let scrollDuration = overflow / speed
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -overflow
                }
                try? await Task.sleep(for: .seconds(scrollDuration + 0.3))
                withAnimation(.easeOut(duration: 0.25)) {
                    offset = 0
                }
            }
    }
}

private struct ContainerWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
