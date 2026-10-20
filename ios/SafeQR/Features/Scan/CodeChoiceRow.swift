import SwiftUI
import SafeQRKit

struct CodeChoiceRow: View {
    let number: Int
    let analysis: CodeAnalysis
    var model: ResultModel?

    private var title: String {
        if case .link(let url) = analysis.content.payload, let host = url.host(percentEncoded: false) {
            return PublicSuffixRules.bundled.registrableDomain(host)
        }
        return analysis.content.title
    }

    private var accessibleTitle: String {
        title == analysis.content.title ? title : "\(analysis.content.title). \(title)"
    }

    var body: some View {
        let verdict = ScanVerdict(analysis: analysis, model: model)
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)").font(.title2.bold()).monospacedDigit()
                .frame(minWidth: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: analysis.content.kind.symbol)
                    .font(.headline).lineLimit(2).truncationMode(.middle)
                Label(verdict.title, systemImage: verdict.symbol)
                    .font(.subheadline).foregroundStyle(verdict.level?.color ?? .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption.bold())
                .foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 14)
        .frame(minHeight: 72)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(number). \(accessibleTitle). \(verdict.title)")
    }
}

@MainActor
struct ScanVerdict {
    let analysis: CodeAnalysis
    let model: ResultModel?

    var level: RiskLevel? {
        if !analysis.hasWebDestination { return analysis.assessment.level }
        guard let model, model.finished else { return nil }
        return model.handoffLevel
    }

    var title: String {
        if model?.linkPending == true { return L10n.text("Checking…") }
        if analysis.hasWebDestination && model?.verdict == nil {
            return L10n.text(model?.finished == true ? "Not checked" : "Waiting for check")
        }
        return (model?.assessment.level ?? analysis.assessment.level).title
    }

    var symbol: String {
        if model?.linkPending == true { return "arrow.trianglehead.2.clockwise.rotate.90" }
        return level?.symbol ?? "link"
    }
}
