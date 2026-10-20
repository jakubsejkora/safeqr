import SwiftUI
import SafeQRKit

struct ScannerVerdictPill: View {
    let code: TrackedCode
    let model: ResultModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var title: String {
        guard code.analysis.hasWebDestination, let model else { return code.title }
        let domain = code.analysis.actions.compactMap { action -> String? in
            guard case .open(let url) = action.kind, let host = url.host(percentEncoded: false) else { return nil }
            return PublicSuffixRules.bundled.registrableDomain(host)
        }.first ?? code.analysis.content.title
        return "\(ScanVerdict(analysis: code.analysis, model: model).title) · \(domain)"
    }

    var body: some View {
        let verdict = ScanVerdict(analysis: code.analysis, model: model)
        HStack(spacing: 10) {
            Image(systemName: verdict.symbol).foregroundStyle(verdict.level?.color ?? .white)
                .symbolEffect(.rotate, options: .repeating, isActive: model?.linkPending == true && !reduceMotion)
                .font(.system(size: 19, weight: .medium))
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(verdict.level == .danger || verdict.level == .caution
                                  ? (verdict.level?.color ?? .clear).opacity(0.18) : .clear))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(code.title). \(verdict.title)")
        .allowsHitTesting(false)
    }
}
