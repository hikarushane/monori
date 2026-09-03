import SwiftUI
import MonoriCore

// MARK: - Monori icon system
//
// Every source icon and bottom-navigator icon in Monori is a hand-drawn
// geometric `Shape`, never an SF Symbol. The style is minimal and constructed
// from primitives (rounded bars, circles, triangles, hairlines) so the whole
// set reads as one family and tints to a single accent. See docs/DESIGN.md.
//
// Adding a new source: draw its mark as a `Shape` here, add a `case` to
// `SourceGlyph`, and it is picked up everywhere `SourceGlyph` is used (the
// Browse source picker and the Library collection list). Do NOT fall back to
// `iconSystemName` for user-facing source icons.
private let monoriSourceStroke = StrokeStyle(
    lineWidth: 1.5,
    lineCap: .round,
    lineJoin: .round
)

private func vx(_ x: CGFloat, in rect: CGRect) -> CGFloat {
    rect.minX + rect.width * x / 24
}

private func vy(_ y: CGFloat, in rect: CGRect) -> CGFloat {
    rect.minY + rect.height * y / 24
}

private func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: vx(x, in: rect), y: vy(y, in: rect))
}

private func scaledRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, in rect: CGRect) -> CGRect {
    CGRect(
        x: vx(x, in: rect),
        y: vy(y, in: rect),
        width: rect.width * w / 24,
        height: rect.height * h / 24
    )
}

private func scaledValue(_ value: CGFloat, in rect: CGRect) -> CGFloat {
    min(rect.width, rect.height) * value / 24
}

// MARK: - Monori icon system
//
// Every source icon and bottom-navigator icon in Monori is a hand-drawn
// geometric `Shape`, never an SF Symbol. The style is minimal and constructed
// from primitives so the whole set reads as one family and tints to a single
// accent.
//
// Adding a new source: draw its mark as a `Shape` here, add a `case` to
// `SourceGlyph`, and it is picked up everywhere `SourceGlyph` is used.

// MARK: Source marks

/// Patreon mark: outlined circle + rounded bar.
struct PatreonMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: scaledRect(11, 3, 10, 10, in: rect))
        p.addRoundedRect(
            in: scaledRect(3, 3, 4, 18, in: rect),
            cornerSize: CGSize(width: scaledValue(1, in: rect), height: scaledValue(1, in: rect))
        )
        return p
    }
}

/// Google Docs source mark, based on the provided triangular geometric icon.
struct GoogleDocsMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Outer triangle
        p.move(to: point(12, 3, in: rect))
        p.addLine(to: point(21, 19, in: rect))
        p.addLine(to: point(3, 19, in: rect))
        p.closeSubpath()

        // Inner lines from center to three vertices
        p.move(to: point(12, 13.6, in: rect))
        p.addLine(to: point(12, 3, in: rect))

        p.move(to: point(12, 13.6, in: rect))
        p.addLine(to: point(3, 19, in: rect))

        p.move(to: point(12, 13.6, in: rect))
        p.addLine(to: point(21, 19, in: rect))

        return p
    }
}

/// AO3 mark: geometric A + O + 3.
struct AO3Mark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        p.move(to: point(4, 20, in: rect))
        p.addLine(to: point(10, 4, in: rect))
        p.addLine(to: point(12, 4, in: rect))

        p.move(to: point(7, 12, in: rect))
        p.addLine(to: point(17, 12, in: rect))

        p.addEllipse(in: scaledRect(8.5, 8.5, 7, 7, in: rect))

        p.move(to: point(16, 4, in: rect))
        p.addArc(
            center: point(16, 8, in: rect),
            radius: scaledValue(4, in: rect),
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        p.addArc(
            center: point(16, 16, in: rect),
            radius: scaledValue(4, in: rect),
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )

        return p
    }
}

/// Vocus mark: 2×2 rounded-square grid.
struct VocusMark: Shape {
    func path(in rect: CGRect) -> Path {
        let corner = CGSize(width: scaledValue(1, in: rect), height: scaledValue(1, in: rect))
        var p = Path()

        p.addRoundedRect(in: scaledRect(4, 4, 7, 7, in: rect), cornerSize: corner)
        p.addRoundedRect(in: scaledRect(13, 4, 7, 7, in: rect), cornerSize: corner)
        p.addRoundedRect(in: scaledRect(4, 13, 7, 7, in: rect), cornerSize: corner)
        p.addRoundedRect(in: scaledRect(13, 13, 7, 7, in: rect), cornerSize: corner)

        return p
    }
}

/// AsianFanfics mark: three vertical bars above a V-shaped book base.
struct AFFMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        p.move(to: point(8, 6, in: rect))
        p.addLine(to: point(8, 14, in: rect))

        p.move(to: point(12, 6, in: rect))
        p.addLine(to: point(12, 15.5, in: rect))

        p.move(to: point(16, 6, in: rect))
        p.addLine(to: point(16, 14, in: rect))

        p.move(to: point(4, 17, in: rect))
        p.addLine(to: point(12, 20, in: rect))
        p.addLine(to: point(20, 17, in: rect))

        return p
    }
}

/// CXC mark: left-opening semicircle with a vertical bar on the right,
/// tracing the CXC logo's actual outline.
struct CXCMark: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        var p = Path()
        p.move(to: point(14.5, 4, in: rect))
        p.addLine(to: point(11, 4, in: rect))
        p.addArc(
            center: point(11, 12, in: rect),
            radius: scaledValue(8, in: rect),
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: true
        )
        p.addLine(to: point(14.5, 20, in: rect))
        p.move(to: point(14.5, 9, in: rect))
        p.addLine(to: point(14.5, 15, in: rect))
        return p
    }
}

/// Slashtw mark ("在水裡寫字"): a geometric water drop — pointed tip at the
/// top, straight tangent edges, round bottom.
struct SlashTWMark: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        var p = Path()
        p.move(to: point(12, 2.69, in: rect))
        p.addLine(to: point(17.66, 8.35, in: rect))
        p.addArc(
            center: point(12, 14, in: rect),
            radius: scaledValue(8, in: rect),
            startAngle: .degrees(-45),
            endAngle: .degrees(225),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

/// Source layers icon: three stacked diamond layers representing multiple
/// reading sources converging.
struct SourceLayersIcon: Shape {
    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }
        var p = Path()
        p.move(to: point(12, 4.5, in: rect))
        p.addLine(to: point(20, 8.5, in: rect))
        p.addLine(to: point(12, 12.5, in: rect))
        p.addLine(to: point(4, 8.5, in: rect))
        p.closeSubpath()
        p.move(to: point(4, 12.5, in: rect))
        p.addLine(to: point(12, 16.5, in: rect))
        p.addLine(to: point(20, 12.5, in: rect))
        p.move(to: point(4, 16.5, in: rect))
        p.addLine(to: point(12, 20.5, in: rect))
        p.addLine(to: point(20, 16.5, in: rect))
        return p
    }
}

/// The shared source icon. One source of truth for the Browse source picker and
/// the Library collection list.
struct SourceGlyph: View {
    let kind: SourceKind

    var body: some View {
        switch kind {
        case .patreon:
            PatreonMark().stroke(.foreground, style: monoriSourceStroke)
        case .googleDocs:
            GoogleDocsMark().stroke(.foreground, style: monoriSourceStroke)
        case .ao3:
            AO3Mark().stroke(.foreground, style: monoriSourceStroke)
        case .vocus:
            VocusMark().stroke(.foreground, style: monoriSourceStroke)
        case .asianFanfics:
            AFFMark().stroke(.foreground, style: monoriSourceStroke)
        case .cxc:
            CXCMark().stroke(.foreground, style: monoriSourceStroke)
        case .slashtw:
            SlashTWMark().stroke(.foreground, style: monoriSourceStroke)
        }
    }
}

// MARK: Library header action marks

/// Clock icon for reading history.
struct LibraryClockIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = scaledValue(9, in: rect)
        let c = point(12, 12, in: rect)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: point(12, 7, in: rect))
        p.addLine(to: point(12, 12, in: rect))
        p.addLine(to: point(15, 15, in: rect))
        return p
    }
}

/// Magnifying glass for search.
struct LibrarySearchIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = scaledValue(8, in: rect)
        let c = point(11, 11, in: rect)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: point(16.65, 16.65, in: rect))
        p.addLine(to: point(21, 21, in: rect))
        return p
    }
}

/// Up/down arrows for sort.
struct LibrarySortIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(7, 20, in: rect))
        p.addLine(to: point(7, 4, in: rect))
        p.move(to: point(3, 8, in: rect))
        p.addLine(to: point(7, 4, in: rect))
        p.addLine(to: point(11, 8, in: rect))
        p.move(to: point(17, 4, in: rect))
        p.addLine(to: point(17, 20, in: rect))
        p.move(to: point(21, 16, in: rect))
        p.addLine(to: point(17, 20, in: rect))
        p.addLine(to: point(13, 16, in: rect))
        return p
    }
}

/// Pill chevron-down indicator (open V, for stroked rendering).
struct PillChevronDown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(6, 9, in: rect))
        p.addLine(to: point(12, 15, in: rect))
        p.addLine(to: point(18, 9, in: rect))
        return p
    }
}

// MARK: Menu dropdown icons

struct MenuCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(20, 6, in: rect))
        p.addLine(to: point(9, 17, in: rect))
        p.addLine(to: point(4, 12, in: rect))
        return p
    }
}

struct MenuBookmarkIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(19, 21, in: rect))
        p.addLine(to: point(12, 16, in: rect))
        p.addLine(to: point(5, 21, in: rect))
        p.addLine(to: point(5, 3, in: rect))
        p.addLine(to: point(19, 3, in: rect))
        p.closeSubpath()
        return p
    }
}

struct MenuCircleCheckIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = scaledValue(9, in: rect)
        let c = point(12, 12, in: rect)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: point(9, 12, in: rect))
        p.addLine(to: point(11, 14, in: rect))
        p.addLine(to: point(15, 10, in: rect))
        return p
    }
}

struct MenuCircleMinusIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = scaledValue(9, in: rect)
        let c = point(12, 12, in: rect)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: point(8, 12, in: rect))
        p.addLine(to: point(16, 12, in: rect))
        return p
    }
}

struct MenuBoltIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(13, 2, in: rect))
        p.addLine(to: point(6, 14, in: rect))
        p.addLine(to: point(12, 14, in: rect))
        p.addLine(to: point(11, 22, in: rect))
        p.addLine(to: point(18, 10, in: rect))
        p.addLine(to: point(12, 10, in: rect))
        p.closeSubpath()
        return p
    }
}

struct MenuFolderIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: point(4, 20, in: rect))
        p.addLine(to: point(4, 5, in: rect))
        p.addLine(to: point(10, 5, in: rect))
        p.addLine(to: point(12, 8, in: rect))
        p.addLine(to: point(20, 8, in: rect))
        p.addLine(to: point(20, 20, in: rect))
        p.closeSubpath()
        return p
    }
}

struct MenuPersonIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = scaledValue(4, in: rect)
        let c = point(12, 8, in: rect)
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: point(5, 20, in: rect))
        p.addCurve(
            to: point(19, 20, in: rect),
            control1: point(5, 14, in: rect),
            control2: point(19, 14, in: rect)
        )
        return p
    }
}

// MARK: UI chrome marks

/// Dropdown indicator: a small outlined downward-pointing triangle.
struct DropdownChevron: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.1, y: h * 0.2))
        p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.8))
        p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.2))
        p.closeSubpath()
        return p
    }
}

// MARK: Bottom-navigator marks

/// Browse: outlined globe + inner compass diamond.
struct BrowseCompass: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        p.addEllipse(in: scaledRect(2, 2, 20, 20, in: rect))

        p.move(to: point(16.24, 7.76, in: rect))
        p.addLine(to: point(14.12, 14.12, in: rect))
        p.addLine(to: point(7.76, 16.24, in: rect))
        p.addLine(to: point(9.88, 9.88, in: rect))
        p.closeSubpath()

        return p
    }
}

/// Library: outlined bookshelf.
struct LibraryBookshelf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        p.move(to: point(4, 19.5, in: rect))
        p.addQuadCurve(
            to: point(6.5, 17, in: rect),
            control: point(4.35, 17.35, in: rect)
        )
        p.addLine(to: point(20, 17, in: rect))

        p.move(to: point(6.5, 2, in: rect))
        p.addLine(to: point(20, 2, in: rect))
        p.addLine(to: point(20, 22, in: rect))
        p.addLine(to: point(6.5, 22, in: rect))
        p.addQuadCurve(
            to: point(4, 19.5, in: rect),
            control: point(4.35, 21.65, in: rect)
        )
        p.addLine(to: point(4, 4.5, in: rect))
        p.addQuadCurve(
            to: point(6.5, 2, in: rect),
            control: point(4.35, 2.35, in: rect)
        )
        p.closeSubpath()

        p.move(to: point(8, 6, in: rect))
        p.addLine(to: point(18, 6, in: rect))

        p.move(to: point(8, 10, in: rect))
        p.addLine(to: point(18, 10, in: rect))

        p.move(to: point(8, 14, in: rect))
        p.addLine(to: point(18, 14, in: rect))

        return p
    }
}

/// Settings: gear outline + center hole.
/// Note: this is a hand-built geometric gear in the same 24×24 coordinate space,
/// not an SVG-path parser output.
struct SettingsGear: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = scaledValue(10, in: rect)
        let inner = scaledValue(8.1, in: rect)
        let hole = scaledValue(3, in: rect)

        var p = Path()

        for i in 0..<16 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let degrees = -90.0 + Double(i) * 22.5
            let radians = degrees * .pi / 180

            let pt = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )

            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }
        p.closeSubpath()

        p.addEllipse(
            in: CGRect(
                x: center.x - hole,
                y: center.y - hole,
                width: hole * 2,
                height: hole * 2
            )
        )

        return p
    }
}

/// Pre-rendered template images for the three tab items. `TabView.tabItem` wants
/// an `Image` (which the system tints for selected/unselected), so each glyph is
/// rasterised once as an always-template image.
@MainActor
enum MonoriTabIcon {
    static let browse = filledOrStroked(BrowseCompass(), filled: false)
    static let library = filledOrStroked(LibraryBookshelf(), filled: false)
    static let settings = filledOrStroked(SettingsGear(), filled: false)

    private static func filledOrStroked<S: Shape>(_ shape: S, filled: Bool, size: CGFloat = 27) -> Image {
        let canvas = CGSize(width: size, height: size)
        let content = ZStack {
            if filled {
                shape.fill(Color.black)
            } else {
                shape.stroke(
                    Color.black,
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: size, height: size)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(canvas)
        let ui = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysTemplate)
        return Image(uiImage: ui)
    }
}
