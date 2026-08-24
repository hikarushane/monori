import SwiftUI

/// Full-width reading-preferences panel shown under the reader's top bar.
/// Buttons never dismiss the panel - readers tap them repeatedly until the
/// text looks right. Tapping the page outside the panel closes it.
struct ReaderPreferencesPanel: View {
    let prefs: ReaderPreferences

    private let preferenceRowMinHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: MonoriSpacing.x2) {
            preferenceRow(
                title: "字體大小",
                value: "\(prefs.fontSize) pt"
            ) {
                controlButton(
                    disabled: prefs.fontSize <= ReaderPreferences.fontSizeRange.lowerBound,
                    accessibilityLabel: "縮小字體",
                    action: { prefs.fontSize -= 1 }
                ) {
                    Text("A−")
                }

                controlButton(
                    disabled: prefs.fontSize >= ReaderPreferences.fontSizeRange.upperBound,
                    accessibilityLabel: "放大字體",
                    action: { prefs.fontSize += 1 }
                ) {
                    Text("A+")
                }
            }

            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)

            preferenceRow(
                title: "行距",
                value: lineSpacingValue
            ) {
                controlButton(
                    disabled: prefs.lineSpacing
                        <= ReaderPreferences.lineSpacingRange.lowerBound + 0.001,
                    accessibilityLabel: "縮小行距",
                    action: {
                        prefs.lineSpacing -= ReaderPreferences.lineSpacingStep
                    }
                ) {
                    Image(systemName: "arrow.down")
                }

                controlButton(
                    disabled: prefs.lineSpacing
                        >= ReaderPreferences.lineSpacingRange.upperBound - 0.001,
                    accessibilityLabel: "放大行距",
                    action: {
                        prefs.lineSpacing += ReaderPreferences.lineSpacingStep
                    }
                ) {
                    Image(systemName: "arrow.up")
                }
            }

            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)

            preferenceRow(title: "主題") {
                ThemeToggle()
            }
        }
        .padding(.horizontal, MonoriSpacing.x3)
        .padding(.vertical, MonoriSpacing.x2)
        .frame(maxWidth: .infinity)
        .background(MonoriPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)
        }
        .accessibilityIdentifier("smoke.readerPrefsPanel")
    }

    private var lineSpacingValue: String {
        String(format: "%.1f", prefs.lineSpacing)
    }

    private func preferenceRow<Controls: View>(
        title: String,
        value: String? = nil,
        @ViewBuilder controls: () -> Controls
    ) -> some View {
        HStack(spacing: MonoriSpacing.x2) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(
                        MonoriTypography.ui(
                            14,
                            relativeTo: .subheadline,
                            weight: .semibold
                        )
                    )
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.ink)

                if let value {
                    Text(value)
                        .font(
                            MonoriTypography.ui(
                                13,
                                relativeTo: .footnote
                            )
                        )
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }
            }

            Spacer(minLength: MonoriSpacing.x3)

            HStack(
                spacing: MonoriSpacing.x1,
                content: controls
            )
        }
        .frame(minHeight: preferenceRowMinHeight)
    }

    private func controlButton<Label: View>(
        disabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .font(
                    MonoriTypography.ui(
                        14,
                        relativeTo: .body,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    disabled
                        ? MonoriPalette.secondaryInk
                        : MonoriPalette.ink
                )
                .frame(width: 52, height: 44)
                .background(
                    MonoriPalette.canvas,
                    in: RoundedRectangle(
                        cornerRadius: MonoriRadius.control,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: MonoriRadius.control,
                        style: .continuous
                    )
                    .stroke(MonoriPalette.divider, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

#if DEBUG
#Preview("閱讀偏好面板") {
    let env = PreviewSupport.emptyEnvironment()
    ReaderPreferencesPanel(prefs: env.prefs)
        .environment(env)
}
#endif
