import SwiftUI

/// Full-width reading-preferences panel shown under the reader's top bar.
/// Buttons never dismiss the panel - readers tap them repeatedly until the
/// text looks right. Tapping the page outside the panel closes it.
struct ReaderPreferencesPanel: View {
    let prefs: ReaderPreferences

    var body: some View {
        VStack(spacing: MonoriSpacing.x2) {
            preferenceRow(title: "字體大小", value: "\(prefs.fontSize) pt") {
                controlButton(disabled: prefs.fontSize <= ReaderPreferences.fontSizeRange.lowerBound,
                              accessibilityLabel: "縮小字體",
                              action: { prefs.fontSize -= 1 }) {
                    Text("A−")
                }
                controlButton(disabled: prefs.fontSize >= ReaderPreferences.fontSizeRange.upperBound,
                              accessibilityLabel: "放大字體",
                              action: { prefs.fontSize += 1 }) {
                    Text("A+")
                }
            }

            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)

            preferenceRow(title: "行距", value: lineSpacingValue) {
                controlButton(disabled: prefs.lineSpacing <= ReaderPreferences.lineSpacingRange.lowerBound + 0.001,
                              accessibilityLabel: "縮小行距",
                              action: { prefs.lineSpacing -= ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.down")
                }
                controlButton(disabled: prefs.lineSpacing >= ReaderPreferences.lineSpacingRange.upperBound - 0.001,
                              accessibilityLabel: "放大行距",
                              action: { prefs.lineSpacing += ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.up")
                }
            }

            Rectangle()
                .fill(MonoriPalette.divider)
                .frame(height: 1)

            HStack(spacing: MonoriSpacing.x2) {
                Text("主題")
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .semibold))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.ink)
                Spacer(minLength: MonoriSpacing.x3)
                ThemeToggle()
            }
        }
        .padding(.horizontal, MonoriSpacing.x3)
        .padding(.top, MonoriSpacing.x2)
        .padding(.bottom, MonoriSpacing.x4)
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

    private func preferenceRow<Controls: View>(title: String,
                                               value: String,
                                               @ViewBuilder controls: () -> Controls) -> some View {
        HStack(spacing: MonoriSpacing.x2) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MonoriTypography.ui(14, relativeTo: .subheadline, weight: .semibold))
                    .tracking(MonoriTypography.uiTracking)
                    .foregroundStyle(MonoriPalette.ink)
                Text(value)
                    .font(MonoriTypography.ui(13, relativeTo: .footnote))
                    .foregroundStyle(MonoriPalette.secondaryInk)
            }
            Spacer(minLength: MonoriSpacing.x3)
            HStack(spacing: MonoriSpacing.x1, content: controls)
        }
    }

    private func controlButton(disabled: Bool,
                               accessibilityLabel: String,
                               action: @escaping () -> Void,
                               @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .font(MonoriTypography.ui(14, relativeTo: .body, weight: .semibold))
                .foregroundStyle(disabled ? MonoriPalette.secondaryInk : MonoriPalette.ink)
                .frame(width: 52, height: 44)
                .background(MonoriPalette.canvas, in: RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
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
