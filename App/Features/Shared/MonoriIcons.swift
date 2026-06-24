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

// MARK: Source marks

/// Patreon brand mark: a vertical rounded bar beside a circle (a pared-down "P").
struct PatreonMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: w * 0.12, y: h * 0.2, width: w * 0.24, height: h * 0.6),
            cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
        path.addEllipse(in: CGRect(x: w * 0.44, y: h * 0.2, width: w * 0.42, height: w * 0.42))
        return path
    }
}

/// Google Drive mark: an outlined triangle.
struct DriveMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.93, y: h * 0.8))
        path.addLine(to: CGPoint(x: w * 0.07, y: h * 0.8))
        path.closeSubpath()
        return path
    }
}

/// The shared source icon. One source of truth for the Browse source picker and
/// the Library collection list, so the two never drift. Renders with the current
/// foreground style, so callers tint it via `.foregroundStyle(...)`.
struct SourceGlyph: View {
    let kind: SourceKind
    var body: some View {
        switch kind {
        case .patreon:
            PatreonMark().fill(.foreground)
        case .googleDocs:
            DriveMark().stroke(.foreground, lineWidth: 1.5)
        }
    }
}

// MARK: Bottom-navigator marks

/// Browse: a globe — outer circle, a meridian ellipse, and an equator hairline.
struct BrowseGlobe: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.addEllipse(in: CGRect(x: w * 0.08, y: h * 0.08, width: w * 0.84, height: h * 0.84))
        p.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.08, width: w * 0.32, height: h * 0.84))
        p.move(to: CGPoint(x: w * 0.10, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.5))
        return p
    }
}

/// Library: three upright rounded "spines" of varying height — the same
/// shelved-books motif as the app icon. Filled, like `PatreonMark`.
struct LibraryBooks: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let bw = w * 0.18
        let r = CGSize(width: w * 0.045, height: w * 0.045)
        var p = Path()
        p.addRoundedRect(in: CGRect(x: w * 0.14, y: h * 0.30, width: bw, height: h * 0.58), cornerSize: r)
        p.addRoundedRect(in: CGRect(x: w * 0.41, y: h * 0.14, width: bw, height: h * 0.74), cornerSize: r)
        p.addRoundedRect(in: CGRect(x: w * 0.68, y: h * 0.36, width: bw, height: h * 0.52), cornerSize: r)
        return p
    }
}

/// Settings: two control sliders — full-width hairlines, each with a knob at a
/// different position. Outlined, like `DriveMark`.
struct SettingsSliders: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let knob = w * 0.12
        var p = Path()
        p.move(to: CGPoint(x: w * 0.1, y: h * 0.34))
        p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.34))
        p.addEllipse(in: CGRect(x: w * 0.62 - knob / 2, y: h * 0.34 - knob / 2, width: knob, height: knob))
        p.move(to: CGPoint(x: w * 0.1, y: h * 0.66))
        p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.66))
        p.addEllipse(in: CGRect(x: w * 0.34 - knob / 2, y: h * 0.66 - knob / 2, width: knob, height: knob))
        return p
    }
}

/// Pre-rendered template images for the three tab items. `TabView.tabItem` wants
/// an `Image` (which the system tints for selected/unselected), so each glyph is
/// rasterised once as an always-template image. Computed lazily on first use
/// from the SwiftUI main-actor render path.
@MainActor
enum MonoriTabIcon {
    static let browse = filledOrStroked(BrowseGlobe(), filled: false)
    static let library = filledOrStroked(LibraryBooks(), filled: true)
    static let settings = filledOrStroked(SettingsSliders(), filled: false)

    private static func filledOrStroked<S: Shape>(_ shape: S, filled: Bool, size: CGFloat = 27) -> Image {
        let canvas = CGSize(width: size, height: size)
        let content = ZStack {
            if filled {
                shape.fill(Color.black)
            } else {
                shape.stroke(Color.black,
                             style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
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
