import SwiftUI
import SafeQRKit

struct PayloadView: View {
    let content: CodeContent
    var compact = false
    var secureURL: URL? = nil

    var body: some View {
        switch content.payload {
        case .link(let url), .appLink(let url):
            VStack(alignment: .leading, spacing: 12) {
                AddressCapsule(url: url)
                if let secureURL {
                    Text(L10n.format("Safe QR opens the secure version: %@", secureURL.absoluteString))
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                ForEach(content.facts.filter { !["domain", "address", "original"].contains($0.id) }) { FactRow(fact: $0) }
            }
        case .payment(let payment): PaymentPayloadView(payment: payment, content: content)
        case .sms(let recipient, let body):
            MessagePayloadView(recipient: value("recipient") ?? recipient, message: value("message") ?? body,
                               facts: content.facts, compact: compact)
        case .messaging: MessagePayloadView(recipient: value("recipient"), message: value("message"), facts: content.facts, compact: compact)
        case .wifi(let network): WiFiPayloadView(network: network, facts: content.facts)
        case .contact: ContactPayloadView(facts: content.facts)
        case .crypto(let request): CryptoPayloadView(request: request, facts: content.facts)
        case .email(let recipient, let subject, let body):
            EmailPayloadView(recipient: value("recipient") ?? recipient, subject: value("subject") ?? subject,
                             message: value("message") ?? body, facts: content.facts)
        case .login, .eSIM: SecretPayloadView(content: content)
        case .event: EventPayloadView(facts: content.facts)
        case .phone(let number):
            VStack(alignment: .leading, spacing: 14) {
                Text(value("phone") ?? number).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit().textSelection(.enabled)
                ForEach(content.facts.filter { $0.id != "phone" }) { FactRow(fact: $0) }
            }
        case .text:
            VStack(alignment: .leading, spacing: 14) {
                if let text = content.facts.first(where: { $0.id == "text" }) {
                    Text(text.value).textSelection(.enabled).padding(.leading, 16)
                        .overlay(alignment: .leading) { Rectangle().fill(.separator).frame(width: 3) }
                }
                ForEach(content.facts.filter { $0.id != "text" }) { FactRow(fact: $0) }
            }
        case .location:
            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.facts) { fact in
                    LabeledContent(fact.label, value: fact.value).textSelection(.enabled)
                }
            }
        }
    }
    private func value(_ id: String) -> String? { content.facts.first { $0.id == id }?.value }
}
