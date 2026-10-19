import SwiftUI
import SafeQRKit

struct ScannerVerdictPill: View {
    let code: TrackedCode
    let model: ResultModel?
    let consentGiven: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var pulse = false

    private var isLink: Bool { code.analysis.hasWebDestination }
    private var pending: Bool { isLink && model?.linkPending == true }
    private var level: RiskLevel? {
        if !isLink { return code.analysis.assessment.level }
        guard let model, model.finished else { return nil }
        return model.handoffLevel
    }
    private var symbol: String {
        if pending { return "arrow.trianglehead.2.clockwise.rotate.90" }
        guard let level else { return "link" }
        switch level {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        }
    }
    private var domain: String {
        code.analysis.actions.compactMap { action -> String? in
            guard case .open(let url) = action.kind, let host = url.host(percentEncoded: false) else { return nil }
            return PublicSuffixRules.bundled.registrableDomain(host)
        }.first ?? code.analysis.content.title
    }
    private var title: String {
        guard isLink else { return code.title }
        let state: String
        if pending { state = L10n.text("Checking…") }
        else if let model, model.verdict != nil { state = model.assessment.level.title }
        else if model?.finished == true && consentGiven { state = L10n.text("Not checked") }
        else { state = consentGiven ? L10n.text("Link") : L10n.text("Tap to check") }
        return "\(state) · \(domain)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).foregroundStyle(level?.color ?? .white)
                    .symbolEffect(.rotate, options: .repeating, isActive: pending && !reduceMotion)
                    .font(.system(size: 19, weight: .medium))
                if isLink && !consentGiven && typeSize.isAccessibilitySize {
                    Text(L10n.text("Tap to check")).font(.subheadline.weight(.semibold))
                        .lineLimit(1).minimumScaleFactor(0.5)
                } else if isLink && !consentGiven {
                    HStack(spacing: 4) {
                        Text(L10n.text("Tap to check") + " ·").layoutPriority(1)
                        Text(domain).truncationMode(.middle)
                    }.font(.subheadline.weight(.semibold)).lineLimit(1)
                } else {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                }
                Image(systemName: "chevron.right").font(.caption.bold())
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .foregroundStyle(.white)
            .glassEffect(.regular.tint(level == .danger || level == .caution ? (level?.color ?? .clear).opacity(0.18) : .clear).interactive())
        }
        .buttonStyle(.plain)
        .scaleEffect(pulse ? 1.04 : 1)
        .accessibilityLabel(title)
        .accessibilityHint(L10n.text("Show the result"))
        .sensoryFeedback(trigger: model?.verdict != nil) { _, ready in ready ? level?.feedback : nil }
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.3)) { pulse = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.3)) { pulse = false }
        }
    }
}
