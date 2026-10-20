import SwiftUI

struct CameraZoomControl: View {
    @Binding var selection: CameraZoom
    let levels: [CameraZoom]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(levels) { zoom($0) }
        }
        .glassEffect(in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func zoom(_ level: CameraZoom) -> some View {
        let selected = selection == level
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                selection = level
            }
        } label: {
            Text(level.title(selected: selected))
                .font(.system(size: selected ? 13 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(selected ? .yellow : .white)
                .frame(width: selected ? 36 : 29, height: selected ? 36 : 29)
                .background(.white.opacity(selected ? 0.13 : 0.04), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
