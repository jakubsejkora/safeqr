import SwiftUI
import SafeQRKit

struct ResultHeader: View {
    let model: ResultModel
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var title: String { model.linkPending ? L10n.text("Checking the link…") : model.assessment.level.title }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            HStack {
                Label(model.analysis.content.title, systemImage: model.analysis.content.kind.symbol)
                    .font(compact ? .caption : .subheadline.weight(.medium)).foregroundStyle(.secondary)
                if compact && !model.linkPending {
                    Spacer()
                    Text("\(model.assessment.score)/100").font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Image(systemName: model.linkPending ? "arrow.trianglehead.2.clockwise.rotate.90" : model.assessment.level == .danger ? "exclamationmark.octagon.fill" : model.assessment.level.symbol)
                    .symbolEffect(.rotate, options: .repeating, isActive: model.linkPending && !reduceMotion)
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(typeSize.isAccessibilitySize || model.linkPending ? 2 : 1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(model.linkPending ? .secondary : model.assessment.level.color)
            .contentTransition(.opacity).accessibilityAddTraits(.isHeader)
            Text(model.headline).font(compact ? .subheadline : .body).fixedSize(horizontal: false, vertical: true)
            RiskMeter(score: model.assessment.score, compact: compact, pending: model.linkPending)
            if model.destinationUnchecked {
                Text(L10n.text("The destination could not be checked. Be careful if you continue."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("verdict-header")
    }
}
