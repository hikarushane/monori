import SwiftUI

/// Shared switch geometry (track + circular thumb) used by Settings toggles.
/// Purely visual: callers own the `isOn` state, tap handling, and all colors.
struct MonoriSwitchControl<ThumbContent: View>: View {
    let isOn: Bool
    let onTrackColor: Color
    let offTrackColor: Color
    let borderColor: Color
    let onThumbColor: Color
    let offThumbColor: Color
    @ViewBuilder let thumbContent: (Bool) -> ThumbContent

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                .fill(isOn ? onTrackColor : offTrackColor)
                .overlay {
                    RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }

            Circle()
                .fill(isOn ? onThumbColor : offThumbColor)
                .frame(width: 26, height: 26)
                .overlay {
                    thumbContent(isOn)
                }
                .padding(3)
        }
        .frame(width: 48, height: 32)
    }
}
