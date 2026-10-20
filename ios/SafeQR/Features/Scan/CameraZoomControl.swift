import SwiftUI

struct CameraZoomControl: View {
    @Binding var ultraWide: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            zoom(ultra: true)
            zoom(ultra: false)
        }
        .padding(3)
        .background(.black.opacity(0.55), in: Capsule())
        .sensoryFeedback(.selection, trigger: ultraWide)
    }

    private func zoom(ultra: Bool) -> some View {
        let selected = ultraWide == ultra
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                ultraWide = ultra
            }
        } label: {
            Text(ultra ? L10n.text(selected ? "0.5×" : ".5") : (selected ? "1×" : "1"))
                .font(.system(size: selected ? 13 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(selected ? .yellow : .white)
                .frame(width: selected ? 36 : 29, height: selected ? 36 : 29)
                .background(.white.opacity(selected ? 0.13 : 0.04), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(ultra ? "Ultra wide" : "Main camera"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
