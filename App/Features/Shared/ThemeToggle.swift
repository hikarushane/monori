import SwiftUI

struct ThemeToggle: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectivelyDark: Bool {
        switch env.appPrefs.appearance {
        case .system: systemColorScheme == .dark
        case .light: false
        case .dark: true
        }
    }

    var body: some View {
        let isDark = effectivelyDark
        let anim: Animation? = reduceMotion ? nil : .easeOut(duration: 0.2)

        HStack(spacing: MonoriSpacing.x1) {
            Button {
                withAnimation(anim) {
                    env.appPrefs.appearance = isDark ? .light : .dark
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                        .fill(isDark
                              ? Color(red: 0.118, green: 0.192, blue: 0.282)
                              : Color(red: 0.929, green: 0.878, blue: 0.753))

                    ZStack {
                        Circle()
                            .fill(isDark
                                  ? Color(red: 0.290, green: 0.612, blue: 0.788)
                                  : Color(red: 0.831, green: 0.659, blue: 0.263))

                        ThemeSunIcon()
                            .stroke(Color(red: 0.984, green: 0.976, blue: 0.973),
                                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .frame(width: 14, height: 14)
                            .opacity(isDark ? 0 : 1)

                        ThemeMoonIcon()
                            .fill(Color(red: 0.984, green: 0.976, blue: 0.973))
                            .frame(width: 13, height: 13)
                            .opacity(isDark ? 1 : 0)
                    }
                    .frame(width: 26, height: 26)
                    .offset(x: isDark ? 12 : -12)
                }
                .frame(width: 56, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("主題切換")
            .accessibilityValue(isDark ? "深色" : "淺色")
            .accessibilityHint("輕點兩下以切換淺色與深色模式")

            Text(isDark ? "Dark" : "Light")
                .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .medium))
                .tracking(MonoriTypography.uiTracking)
                .foregroundStyle(MonoriPalette.ink)
                .contentTransition(.opacity)
                .frame(width: 38, alignment: .leading)
        }
    }
}

struct ThemeSunIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let s = min(rect.width, rect.height)
        let coreR = s * 0.2
        let rayInner = s * 0.32
        let rayOuter = s * 0.46
        var p = Path()
        p.addEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR,
                                width: coreR * 2, height: coreR * 2))
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4
            p.move(to: CGPoint(x: center.x + rayInner * cos(a),
                               y: center.y + rayInner * sin(a)))
            p.addLine(to: CGPoint(x: center.x + rayOuter * cos(a),
                                  y: center.y + rayOuter * sin(a)))
        }
        return p
    }
}

struct ThemeMoonIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let cx = rect.midX
        let cy = rect.midY
        let R = s * 0.42
        let d = s * 0.24
        let r = s * 0.38
        let xI = (d * d + R * R - r * r) / (2 * d)
        let yI = sqrt(max(0, R * R - xI * xI))
        let outerTop = Angle.radians(atan2(-yI, xI))
        let outerBottom = Angle.radians(atan2(yI, xI))
        let innerBottom = Angle.radians(atan2(yI, xI - d))
        let innerTop = Angle.radians(atan2(-yI, xI - d))
        var p = Path()
        p.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                 startAngle: outerTop, endAngle: outerBottom, clockwise: true)
        p.addArc(center: CGPoint(x: cx + d, y: cy), radius: r,
                 startAngle: innerBottom, endAngle: innerTop, clockwise: false)
        p.closeSubpath()
        return p
    }
}
