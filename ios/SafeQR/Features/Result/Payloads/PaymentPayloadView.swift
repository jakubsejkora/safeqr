import SwiftUI
import SafeQRKit

struct PaymentPayloadView: View {
    let payment: PaymentRequest
    let content: CodeContent
    private let transferFields: Set<String> = [
        "amount", "account", "bank", "recipient", "bic", "variableSymbol", "specificSymbol", "constantSymbol", "message", "dueDate"
    ]
    private var slipFacts: [Fact] {
        payment.format == .czechSPD ? content.facts.filter { transferFields.contains($0.id) } : content.facts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            transferSlip
            if payment.format == .czechSPD {
                let extra = content.facts.filter { !transferFields.contains($0.id) && $0.id != "format" }
                if !extra.isEmpty {
                    DetailSection(title: L10n.text("Other fields in the original code")) {
                        Text(L10n.text("These fields are not included in the payment image."))
                            .font(.footnote).foregroundStyle(.secondary)
                        ForEach(extra) { FactRow(fact: $0) }
                    }
                }
            }
        }
    }

    private var transferSlip: some View {
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
            if payment.format == .czechSPD, payment.amount == nil, let currency = payment.currency {
                LabeledContent(L10n.text("Currency"), value: currency)
            }
            ForEach(slipFacts.filter { !["amount", "recipient", "bank"].contains($0.id) && !(payment.iban != nil && $0.id == "account") }) { fact in
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
