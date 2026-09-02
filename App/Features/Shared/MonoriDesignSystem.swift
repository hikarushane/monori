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

/// Environment-driven visual metrics for Monori's custom chrome. Regular
/// horizontal layouts receive more breathing room without changing iPhone or
/// iPad Split View sizing. Keep system navigation and toolbar dimensions under
/// SwiftUI's control; these values are only for Monori-owned content.
struct MonoriUIMetrics: Equatable {
    struct Spacing: Equatable {
        let x1: CGFloat
        let x2: CGFloat
        let x3: CGFloat
        let x4: CGFloat
        let x5: CGFloat
        let x6: CGFloat
        let x8: CGFloat
    }

    let isRegularWidth: Bool
    let spacing: Spacing
    let contentHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let rowInformationSpacing: CGFloat
    let libraryRowContentSpacing: CGFloat
    let librarySourceIconSize: CGFloat
    let librarySourceSlotWidth: CGFloat
    let sectionSpacing: CGFloat
    let libraryTitleFontSize: CGFloat
    let bodyFontSize: CGFloat
    let secondaryFontSize: CGFloat
    let sectionTitleFontSize: CGFloat
    let buttonLabelFontSize: CGFloat
    let emptyStateTitleFontSize: CGFloat
    let emptyStateDescriptionFontSize: CGFloat
    let libraryEmptyStateTitleFontSize: CGFloat
    let filterLabelFontSize: CGFloat
    let accessoryIconSize: CGFloat
    let actionIconSize: CGFloat
    let primaryActionIconSize: CGFloat
    let emptyStateIconSize: CGFloat
    let largeTitleFontSize: CGFloat
    let captionFontSize: CGFloat
    let footnoteFontSize: CGFloat
    let readerTopBarHeight: CGFloat
    let chapterProgressFontSize: CGFloat

    init(horizontalSizeClass: UserInterfaceSizeClass?) {
        isRegularWidth = horizontalSizeClass == .regular
        if isRegularWidth {
            spacing = Spacing(x1: 12, x2: 24, x3: 36, x4: 48,
                              x5: 56, x6: 64, x8: 80)
            contentHorizontalPadding = 32
            rowVerticalPadding = 16
            rowInformationSpacing = 8
            libraryRowContentSpacing = 8
            librarySourceIconSize = 33
            librarySourceSlotWidth = 42
            sectionSpacing = 24
            libraryTitleFontSize = 26
            bodyFontSize = 24
            secondaryFontSize = 21
            sectionTitleFontSize = 20
            buttonLabelFontSize = 24
            emptyStateTitleFontSize = 27
            emptyStateDescriptionFontSize = 24
            libraryEmptyStateTitleFontSize = 36
            filterLabelFontSize = 21
            accessoryIconSize = 24
            actionIconSize = 30
            primaryActionIconSize = 30
            emptyStateIconSize = 48
            largeTitleFontSize = 48
            captionFontSize = 17
            footnoteFontSize = 20
            readerTopBarHeight = 96
            chapterProgressFontSize = 18
        } else {
            spacing = Spacing(x1: MonoriSpacing.x1, x2: MonoriSpacing.x2,
                              x3: MonoriSpacing.x3, x4: MonoriSpacing.x4,
                              x5: MonoriSpacing.x5, x6: MonoriSpacing.x6,
                              x8: MonoriSpacing.x8)
            contentHorizontalPadding = MonoriSpacing.x3
            rowVerticalPadding = MonoriSpacing.x2
            rowInformationSpacing = MonoriSpacing.x1
            libraryRowContentSpacing = MonoriSpacing.x2
            librarySourceIconSize = 22
            librarySourceSlotWidth = 28
            sectionSpacing = MonoriSpacing.x3
            libraryTitleFontSize = 17
            bodyFontSize = 16
            secondaryFontSize = 14
            sectionTitleFontSize = 13
            buttonLabelFontSize = 16
            emptyStateTitleFontSize = 18
            emptyStateDescriptionFontSize = 16
            libraryEmptyStateTitleFontSize = 24
            filterLabelFontSize = 14
            accessoryIconSize = 16
            actionIconSize = 20
            primaryActionIconSize = 20
            emptyStateIconSize = 32
            largeTitleFontSize = 32
            captionFontSize = 11
            footnoteFontSize = 13
            readerTopBarHeight = 64
            chapterProgressFontSize = 12
        }
    }

    static let compact = MonoriUIMetrics(horizontalSizeClass: .compact)

    func contentMargin(in containerWidth: CGFloat, maxContentWidth: CGFloat) -> CGFloat {
        max(contentHorizontalPadding, (containerWidth - maxContentWidth) / 2)
    }
}

private struct MonoriUIMetricsKey: EnvironmentKey {
    static let defaultValue = MonoriUIMetrics.compact
}

extension EnvironmentValues {
    var monoriUIMetrics: MonoriUIMetrics {
        get { self[MonoriUIMetricsKey.self] }
        set { self[MonoriUIMetricsKey.self] = newValue }
    }
}

enum MonoriRadius {
    static let control: CGFloat = 12
    static let container: CGFloat = 20
}

struct MonoriBackButton: View {
    @Environment(\.monoriUIMetrics) private var metrics
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(MonoriTypography.ui(metrics.primaryActionIconSize,
                                           relativeTo: .title3,
                                           weight: .semibold))
                .foregroundStyle(MonoriPalette.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
