import SwiftUI

struct MonoriSwitchControl<ThumbContent: View>: View {
    @Environment(\.monoriUIMetrics) private var metrics
    let isOn: Bool
    let onTrackColor: Color
    let offTrackColor: Color
    let borderColor: Color
    let onThumbColor: Color
    let offThumbColor: Color
    @ViewBuilder let thumbContent: (Bool) -> ThumbContent

    var body: some View {
        let thumbPadding: CGFloat = metrics.isRegularWidth ? 4.5 : 3
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                .fill(isOn ? onTrackColor : offTrackColor)
                .overlay {
                    RoundedRectangle(cornerRadius: MonoriRadius.control, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }

            Circle()
                .fill(isOn ? onThumbColor : offThumbColor)
                .frame(width: metrics.switchThumbSize, height: metrics.switchThumbSize)
                .overlay {
                    thumbContent(isOn)
                }
                .padding(thumbPadding)
        }
        .frame(width: metrics.switchTrackWidth, height: metrics.switchTrackHeight)
        .frame(minWidth: 44, minHeight: 44)
    }
}
