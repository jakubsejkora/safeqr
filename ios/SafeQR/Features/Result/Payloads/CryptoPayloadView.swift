import SwiftUI
import SafeQRKit

struct CryptoPayloadView: View {
    let request: CryptoRequest
    let facts: [Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let amount = facts.first(where: { $0.id == "amount" }) {
                Text(amount.value).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
            }
            if let network = facts.first(where: { $0.id == "network" }) { Text(network.value).font(.headline).foregroundStyle(.secondary) }
            Text(request.address).font(.system(.body, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                .accessibilityLabel(request.address)
            DisclosureGroup(L10n.text("Full address")) {
                if let account = facts.first(where: { $0.id == "account" }) { FactRow(fact: account).padding(.top, 8) }
            }.font(.subheadline)
            ForEach(facts.filter { !["amount", "account", "network"].contains($0.id) }) { FactRow(fact: $0) }
        }
    }
}
