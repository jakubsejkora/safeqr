import SwiftUI
import SafeQRKit

struct PaymentPayloadView: View {
    let payment: PaymentRequest
    let content: CodeContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let amount = content.facts.first(where: { $0.id == "amount" }) {
                Text(amount.value).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let recipient = content.facts.first(where: { $0.id == "recipient" })?.value { Text(recipient).font(.headline) }
            Divider()
            if let iban = payment.iban {
                Text(Self.grouped(iban)).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if let bank = content.facts.first(where: { $0.id == "bank" })?.value { Text(bank).font(.subheadline).foregroundStyle(.secondary) }
            }
            ForEach(content.facts.filter { !["amount", "recipient", "bank"].contains($0.id) && !(payment.iban != nil && $0.id == "account") }) { fact in
                FactRow(fact: fact)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.4), lineWidth: 0.5) }
    }

    static func grouped(_ iban: String) -> String {
        let characters = Array(iban.filter { !$0.isWhitespace })
        return stride(from: 0, to: characters.count, by: 4).map { String(characters[$0..<min($0 + 4, characters.count)]) }.joined(separator: " ")
    }
}
