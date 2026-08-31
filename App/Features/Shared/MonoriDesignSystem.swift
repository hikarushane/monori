import SwiftUI

/// Central semantic tokens for Monori's Uguisu Zen interface.
///
/// Use these names rather than system fills, bars, or ad-hoc RGB values so
/// light and dark appearances preserve the same visual hierarchy.
enum MonoriPalette {
    static let canvas = Color("MonoriCanvas")
    static let surface = Color("MonoriSurface")
    static let ink = Color("MonoriInk")
    static let secondaryInk = Color("MonoriSecondaryInk")
    static let divider = Color("MonoriDivider")
    static let navigationAccent = Color("MonoriNavigationGreen")
    static let brandAccent = Color("MonoriBrandGreen")
    static let bookmark = Color("MonoriBookmark")
    static let highlight = Color("MonoriHighlight")
}

enum MonoriTypography {
    static let uiFamily = "Manrope-Regular"
    static let readerFamily = "SourceSerif4Variable-Roman"
    static let readerCJKFamily = "NotoSerifTC-Regular"

    static func ui(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body,
                   weight: Font.Weight = .regular) -> Font {
        Font.custom(uiFamily, size: size, relativeTo: textStyle).weight(weight)
    }

    static func reader(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body,
                       weight: Font.Weight = .regular) -> Font {
        Font.custom(readerFamily, size: size, relativeTo: textStyle).weight(weight)
    }

    static let uiTracking: CGFloat = 0.32
    static let navigationTracking: CGFloat = 0.55
}

enum MonoriSpacing {
    static let x1: CGFloat = 8
    static let x2: CGFloat = 16
    static let x3: CGFloat = 24
    static let x4: CGFloat = 32
    static let x5: CGFloat = 40
    static let x6: CGFloat = 48
    static let x8: CGFloat = 64
}

enum MonoriRadius {
    static let control: CGFloat = 12
    static let container: CGFloat = 20
}

struct MonoriBackButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(MonoriTypography.ui(19, relativeTo: .title3, weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
