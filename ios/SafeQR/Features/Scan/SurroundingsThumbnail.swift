import SwiftUI

struct SurroundingsThumbnail: View {
    let image: UIImage
    let captureCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image).resizable().scaledToFill().frame(width: 100, height: 76).clipped()
            Text(L10n.text("0.5× · Surroundings")).font(.caption2.weight(.medium))
                .frame(width: 100).padding(.vertical, 6)
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(pulse ? 1.06 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Live view of the surroundings"))
        .onChange(of: captureCount) { old, new in
            guard new > old, !reduceMotion else { return }
            withAnimation(.spring(duration: 0.25)) { pulse = true }
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(duration: 0.25)) { pulse = false }
            }
        }
    }
}
