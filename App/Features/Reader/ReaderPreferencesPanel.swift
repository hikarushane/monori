import SwiftUI
import MonoriCore

/// Full-width reading-preferences panel shown under the reader's top bar.
/// Buttons never dismiss the panel - readers tap them repeatedly until the
/// text looks right. Tapping the page outside the panel closes it.
struct ReaderPreferencesPanel: View {
    let prefs: ReaderPreferences
    @Environment(\.monoriUIMetrics) private var metrics

    private let preferenceRowMinHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: metrics.spacing.x2) {
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

            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)

            preferenceRow(title: "簡繁轉換") {
                conversionToggle(.toTraditional, label: "簡轉繁")
                conversionToggle(.toSimplified, label: "繁轉簡")
            }
        }
        .padding(.horizontal, metrics.contentHorizontalPadding)
        .padding(.vertical, metrics.spacing.x2)
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
        HStack(spacing: metrics.spacing.x2) {
            VStack(alignment: .leading, spacing: metrics.rowInformationSpacing) {
                Text(title)
                    .font(
                        MonoriTypography.ui(
                            metrics.bodyFontSize,
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
                            metrics.secondaryFontSize,
                                relativeTo: .footnote
                            )
                        )
                        .foregroundStyle(MonoriPalette.secondaryInk)
                }
            }

            Spacer(minLength: metrics.spacing.x3)

            HStack(
                spacing: metrics.spacing.x1,
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
                        metrics.buttonLabelFontSize,
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

    private func conversionToggle(_ mode: ChineseConversion, label: String) -> some View {
        let isActive = prefs.chineseConversion == mode
        return Button {
            prefs.chineseConversion = isActive ? .off : mode
        } label: {
            Text(label)
                .font(
                    MonoriTypography.ui(
                        metrics.buttonLabelFontSize,
                        relativeTo: .body,
                        weight: .semibold
                    )
                )
                .foregroundStyle(isActive ? MonoriPalette.canvas : MonoriPalette.ink)
                .padding(.horizontal, metrics.spacing.x2)
                .frame(height: 44)
                .background(
                    isActive ? MonoriPalette.ink : MonoriPalette.canvas,
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
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("閱讀偏好面板") {
    let env = PreviewSupport.emptyEnvironment()
    ReaderPreferencesPanel(prefs: env.prefs)
        .environment(env)
}
#endif
