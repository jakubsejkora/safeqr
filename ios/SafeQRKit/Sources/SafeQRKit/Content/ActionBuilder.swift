import Foundation

struct ActionBuilder {
    let localizer: Localizer

    func build(_ parsed: ParsedCode, raw: String, assessment: RiskAssessment) -> [CodeAction] {
        var actions: [CodeAction] = []
        if parsed.allowsHandoff, let handoff = handoff(parsed.payload, raw: raw),
           !assessment.findings.contains(where: { ["payment.checksum", "payment.invalidIBAN", "crypto.checksum", "phone.forwarding", "phone.serviceCode", "link.unsafeScheme"].contains($0.id) }) {
            let title = localizer.text("action.\(handoff.id)")
            let warnings = assessment.findings.filter { $0.severity >= .warning }.prefix(2).map(\.detail)
            let message = (assessment.consequences + warnings).uniqued(by: { $0 }).joined(separator: " ")
            actions.append(CodeAction(id: handoff.id, kind: handoff.kind, title: title, isPrimary: true,
                                      confirmation: Confirmation(title: localizer.text("confirmation.\(handoff.id)"),
                                                                 message: message,
                                                                 confirmTitle: title, isRisky: assessment.level != .safe)))
        }
        actions.append(CodeAction(id: "copy", kind: .copy(raw), title: localizer.text("action.copy"), confirmation: nil))
        actions.append(CodeAction(id: "share", kind: .share(raw), title: localizer.text("action.share"), confirmation: nil))
        return actions
    }

    private func handoff(_ payload: Payload, raw: String) -> (id: String, kind: CodeAction.Kind)? {
        switch payload {
        case .link(let url), .appLink(let url): return ("open", .open(url))
        case .payment(let payment) where payment.format == .upi:
            return URL(string: ParseSupport.trimmed(raw)).map { ("payment", .open($0)) }
        case .crypto:
            guard let scheme = ParseSupport.scheme(ParseSupport.trimmed(raw)), ["bitcoin", "ethereum", "lightning", "litecoin", "solana", "tron"].contains(scheme),
                  let url = URL(string: ParseSupport.trimmed(raw)) else { return nil }
            return ("wallet", .open(url))
        case .sms(let recipient, let body): return ("sms", .sendSMS(recipient: recipient, body: body))
        case .phone(let number): return ("call", .call(phoneNumber: number))
        case .email(let recipient, let subject, let body): return ("email", .composeEmail(recipient: recipient, subject: subject, body: body))
        case .wifi(let network): return ("wifi", .joinWiFi(ssid: network.ssid, password: network.password, security: network.security))
        case .contact(let contact): return ("contact", .addContact(vCard: contact.vCard))
        case .event(let event): return ("event", .addEvent(iCalendar: event.iCalendar))
        case .location(let latitude, let longitude, let query):
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)")]
            if let query { components?.queryItems?.append(URLQueryItem(name: "q", value: query)) }
            return components?.url.map { ("map", .open($0)) }
        case .messaging(let link): return ("message", .open(link.url))
        case .login(let login):
            if [.authenticatorSetup, .authenticatorExport].contains(login.service), let url = URL(string: ParseSupport.trimmed(raw)) { return ("authenticator", .open(url)) }
            return nil
        case .payment, .eSIM, .text: return nil
        }
    }
}
