import SwiftUI
import UIKit

// MARK: Uguisu Zen menu color tokens

let uguisuGreen = Color(red: 0xA8/255, green: 0xB9/255, blue: 0xA0/255)
let uguisuMenuIconGrey = MonoriPalette.secondaryInk

private let menuBackground = Color(uiColor: .init { traits in
    traits.userInterfaceStyle == .dark
        ? .init(red: 0.20, green: 0.19, blue: 0.17, alpha: 1)
        : .white
})

private let zeroBadgeColor = Color(uiColor: .init { traits in
    traits.userInterfaceStyle == .dark
        ? .init(red: 0.35, green: 0.34, blue: 0.33, alpha: 1)
        : .init(red: 0xBD/255, green: 0xBB/255, blue: 0xB7/255, alpha: 1)
})

// MARK: Uguisu Zen menu components

struct UguisuMenuContainer<Content: View>: View {
    var width: CGFloat = 200
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 6)
            .background(menuBackground, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MonoriPalette.divider, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 8)
            .frame(width: width)
    }
}

struct UguisuMenuRow<Icon: View>: View {
    @ViewBuilder var icon: () -> Icon
    let label: String
    var count: Int? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon()
                    .frame(width: 17, height: 17)
                Text(label)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(MonoriPalette.ink)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(count > 0 ? MonoriPalette.secondaryInk : zeroBadgeColor)
                }
                if selected {
                    MenuCheckmark()
                        .stroke(uguisuGreen,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 14)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct UguisuMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(MonoriPalette.divider)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}
