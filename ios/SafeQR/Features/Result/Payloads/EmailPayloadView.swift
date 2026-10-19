import SwiftUI
import SafeQRKit

struct EmailPayloadView: View {
    let recipient: String
    let subject: String?
    let message: String?
    let facts: [Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.format("To: %@", recipient)).textSelection(.enabled)
            Divider()
            if let subject {
                Text(subject).font(.headline).textSelection(.enabled)
                Divider()
            }
            if let message { Text(message).textSelection(.enabled).padding(.vertical, 8) }
            ForEach(facts.filter { !["recipient", "subject", "message"].contains($0.id) }) { FactRow(fact: $0) }
        }
    }
}
