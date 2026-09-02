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

/// CXC mark: a crescent moon, echoing the white "C" crescent in CXC's own
/// logo. Built as a single closed boundary — an outer disk's major arc (the
/// moon's outer edge) plus a smaller, offset disk's minor arc (the inner
/// edge of the "bite") — meeting at two tapered tips, the same way outlined
/// crescent-moon glyphs are constructed in other icon sets.
struct CXCMark: Shape {
    func path(in rect: CGRect) -> Path {
        let outerCenter = point(12, 12, in: rect)
        let outerRadius = scaledValue(8, in: rect)
        let innerCenter = point(18, 10, in: rect)
        let innerRadius = scaledValue(7.5, in: rect)

        let dx = innerCenter.x - outerCenter.x
        let dy = innerCenter.y - outerCenter.y
        let d = sqrt(dx * dx + dy * dy)

        // Guard a degenerate (zero-size) rect: the two centers would
        // coincide, making the intersection below divide by zero.
        guard d > 0 else { return Path() }

        // Standard circle-circle intersection: `a` is the distance from
        // outerCenter to the midpoint of the chord joining the two tips;
        // `h` is half the chord length.
        let a = (outerRadius * outerRadius - innerRadius * innerRadius + d * d) / (2 * d)
        let h = sqrt(max(outerRadius * outerRadius - a * a, 0))
        let midX = outerCenter.x + a * dx / d
        let midY = outerCenter.y + a * dy / d
        let offsetX = -dy / d * h
        let offsetY = dx / d * h

        let tip1 = CGPoint(x: midX + offsetX, y: midY + offsetY)
        let tip2 = CGPoint(x: midX - offsetX, y: midY - offsetY)

        var p = Path()
        p.move(to: tip1)
        // Outer disk's major arc: the moon's outer edge, away from the bite.
        p.addArc(
            center: outerCenter,
            radius: outerRadius,
            startAngle: .radians(atan2(tip1.y - outerCenter.y, tip1.x - outerCenter.x)),
            endAngle: .radians(atan2(tip2.y - outerCenter.y, tip2.x - outerCenter.x)),
            clockwise: false
        )
        // Inner disk's minor arc: closes back to the first tip.
        p.addArc(
            center: innerCenter,
            radius: innerRadius,
            startAngle: .radians(atan2(tip2.y - innerCenter.y, tip2.x - innerCenter.x)),
            endAngle: .radians(atan2(tip1.y - innerCenter.y, tip1.x - innerCenter.x)),
            clockwise: true
        )
        p.closeSubpath()

        return p
    }
}

/// Placeholder mark for a source that has not received its real hand-drawn
/// icon yet (a plain outlined circle). Used for `.slashtw` until its mark is
/// drawn; deliberately generic so it reads as unfinished.
struct PlaceholderSourceMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: scaledRect(4, 4, 16, 16, in: rect))
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
            PlaceholderSourceMark().stroke(.foreground, style: monoriSourceStroke)
        }
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
