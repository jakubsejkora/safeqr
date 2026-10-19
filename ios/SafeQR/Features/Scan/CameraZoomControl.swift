import SwiftUI

struct CameraZoomControl: View {
    @Binding var ultraWide: Bool

    var body: some View {
        HStack(spacing: 2) {
            zoom("0.5×", selected: ultraWide) { ultraWide = true }
            zoom("1×", selected: !ultraWide) { ultraWide = false }
        }
        .padding(4).glassEffect(in: Capsule())
    }

    private func zoom(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(.subheadline, design: .rounded, weight: selected ? .bold : .regular))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4).frame(width: 48, height: 48)
                .background(selected ? .white.opacity(0.2) : .clear, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "1×" ? L10n.text("Main camera") : L10n.text("Surroundings camera"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
