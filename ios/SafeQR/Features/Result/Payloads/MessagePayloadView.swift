import SwiftUI
import SafeQRKit

struct MessagePayloadView: View {
    @Environment(\.appTheme) private var theme
    let recipient: String?
    let message: String?
    let facts: [Fact]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            if let recipient {
                Text(L10n.format("To: %@", recipient)).font(.headline).monospacedDigit().textSelection(.enabled)
            }
            if let message, !message.isEmpty {
                HStack {
                    Spacer(minLength: 28)
                    Text(message).font(compact ? .callout : .body).textSelection(.enabled).padding(compact ? 10 : 16)
                        .foregroundStyle(theme.onAccent).background(theme.accent, in: RoundedRectangle(cornerRadius: 22))
                }
            }
            ForEach(facts.filter { !["recipient", "message"].contains($0.id) }) { fact in
                if compact && fact.id == "price" {
                    Text(fact.value).font(.caption).foregroundStyle(RiskLevel.caution.color)
                        .fixedSize(horizontal: false, vertical: true)
                } else { FactRow(fact: fact) }
            }
        }
    }
}
