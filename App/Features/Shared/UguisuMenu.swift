import SwiftUI

// MARK: Uguisu Zen menu color tokens

let uguisuGreen = Color(red: 0xA8/255, green: 0xB9/255, blue: 0xA0/255)
let uguisuMenuIconGrey = Color(red: 0x73/255, green: 0x72/255, blue: 0x6E/255)
private let menuBorderColor = Color(red: 0xF0/255, green: 0xEC/255, blue: 0xE7/255)
private let zeroBadgeColor = Color(red: 0xBD/255, green: 0xBB/255, blue: 0xB7/255)

// MARK: Uguisu Zen menu components

struct UguisuMenuContainer<Content: View>: View {
    var width: CGFloat = 200
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 6)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(menuBorderColor, lineWidth: 1)
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
                        .foregroundStyle(count > 0 ? uguisuMenuIconGrey : zeroBadgeColor)
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
            .fill(menuBorderColor)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }
}
