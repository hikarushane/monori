import SwiftUI

/// Full-width reading-preferences panel shown under the reader's top bar.
/// Buttons never dismiss the panel - readers tap them repeatedly until the
/// text looks right. Tapping the page outside the panel closes it.
struct ReaderPreferencesPanel: View {
    let prefs: ReaderPreferences

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                controlButton(disabled: prefs.fontSize <= ReaderPreferences.fontSizeRange.lowerBound,
                              accessibilityLabel: "縮小字體",
                              action: { prefs.fontSize -= 1 }) {
                    Text("A").font(.system(size: 15))
                }
                controlButton(disabled: prefs.fontSize >= ReaderPreferences.fontSizeRange.upperBound,
                              accessibilityLabel: "放大字體",
                              action: { prefs.fontSize += 1 }) {
                    Text("A").font(.system(size: 26))
                }
            }
            GridRow {
                controlButton(disabled: prefs.lineSpacing <= ReaderPreferences.lineSpacingRange.lowerBound + 0.001,
                              accessibilityLabel: "縮小行距",
                              action: { prefs.lineSpacing -= ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
                }
                controlButton(disabled: prefs.lineSpacing >= ReaderPreferences.lineSpacingRange.upperBound - 0.001,
                              accessibilityLabel: "放大行距",
                              action: { prefs.lineSpacing += ReaderPreferences.lineSpacingStep }) {
                    Image(systemName: "arrow.up.and.line.horizontal.and.arrow.down")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .accessibilityIdentifier("smoke.readerPrefsPanel")
    }

    private func controlButton(disabled: Bool,
                               accessibilityLabel: String,
                               action: @escaping () -> Void,
                               @ViewBuilder label: () -> some View) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.secondarySystemFill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}
