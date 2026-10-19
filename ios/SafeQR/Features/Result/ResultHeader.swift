import SwiftUI
import SafeQRKit

struct ResultHeader: View {
    let model: ResultModel
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            HStack {
                Label(model.analysis.content.title, systemImage: model.analysis.content.kind.symbol)
                    .font(compact ? .caption : .subheadline.weight(.medium)).foregroundStyle(.secondary)
                if compact {
                    Spacer()
                    Text("\(model.assessment.score)/100").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Image(systemName: model.assessment.level == .danger ? "exclamationmark.octagon.fill" : model.assessment.level.symbol)
                    .accessibilityHidden(true)
                Text(model.assessment.level.title)
                    .lineLimit(typeSize.isAccessibilitySize && model.assessment.level.title.contains(" ") ? 2 : 1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(model.assessment.level.color)
            .contentTransition(.opacity).accessibilityAddTraits(.isHeader)
            Text(model.headline).font(compact ? .subheadline : .body).fixedSize(horizontal: false, vertical: true)
            RiskMeter(score: model.assessment.score, compact: compact)
        }
        .accessibilityIdentifier("verdict-header")
    }
}
