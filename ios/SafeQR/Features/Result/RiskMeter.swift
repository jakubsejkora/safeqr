import SwiftUI
import SafeQRKit

enum RiskMeterScale {
    static func fraction(_ score: Int) -> Double { Double(min(100, max(0, score))) / 100 }
    static func position(_ score: Int, width: Double, knob: Double = 10) -> Double {
        let inset = min(max(0, width) / 2, knob / 2)
        return inset + fraction(score) * max(0, width - inset * 2)
    }
}

struct RiskMeter: View {
    let score: Int
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geometry in
                Capsule().fill(LinearGradient(stops: [.init(color: RiskLevel.safe.color, location: 0),
                                                      .init(color: RiskLevel.caution.color, location: 0.45),
                                                      .init(color: RiskLevel.danger.color, location: 1)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6).padding(.vertical, 4)
                Circle().fill(.primary).frame(width: 10, height: 10)
                    .overlay { Circle().stroke(.background, lineWidth: 2) }
                    .position(x: RiskMeterScale.position(score, width: geometry.size.width), y: 7)
            }.frame(height: 14)
            if !typeSize.isAccessibilitySize {
                HStack {
                    Text(L10n.text("Safe"))
                    Spacer()
                    Text(L10n.text("Caution"))
                    Spacer()
                    Text(L10n.text("Danger"))
                }.font(.caption2).foregroundStyle(.secondary)
            }
            if !compact {
                Text(L10n.format("Risk score: %lld out of 100", score))
                    .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("Risk score: %lld out of 100", score))
    }
}
