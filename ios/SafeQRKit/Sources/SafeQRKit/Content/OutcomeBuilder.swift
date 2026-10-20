import Foundation

struct OutcomeBuilder {
    let localizer: Localizer

    func consequences(_ parsed: ParsedCode) -> [String] {
        let payload = parsed.payload
        if case .login(let login) = payload, login.service == .authenticatorExport && login.accountCount == 0 {
            return [localizer.text("consequence.emptyExport")]
        }
        if case .payment(let payment) = payload, payment.format == .payBySquare {
            return [localizer.text("consequence.payBySquare")]
        }
        guard parsed.allowsHandoff else { return [localizer.text("consequence.unavailable")] }
        switch payload {
        case .link(let url): return [localizer.text("consequence.link", url.host(percentEncoded: false) ?? "")]
        case .payment(let payment):
            if payment.checksum == .invalid || payment.iban.map({ !IBAN.isValid($0) }) == true {
                return [localizer.text("consequence.unavailable")]
            }
            if payment.format == .czechInvoice { return [localizer.text("consequence.invoice")] }
            let amount = payment.amount.map { localizer.amount($0, currency: payment.currency ?? localizer.text("value.currencyUnknown")) }
                ?? localizer.text("value.amountUnknown")
            var account = ContentBuilder(localizer: localizer).account(payment) ?? localizer.text("value.accountUnknown")
            if let bank = payment.bankName { account += " (\(bank))" }
            return [localizer.text("consequence.payment", amount, account), localizer.text("consequence.paymentConfirm")]
        case .crypto(let crypto): return [localizer.text(crypto.checksum == .invalid ? "consequence.unavailable" : "consequence.crypto")]
        case .sms(let recipient, _): return [localizer.text("consequence.sms", recipient)]
        case .phone(let number):
            let service = number.contains("*") || number.contains("#")
            return [localizer.text(service ? "consequence.serviceCode" : "consequence.phone", number)]
        case .email(let recipient, _, _): return [localizer.text("consequence.email", recipient)]
        case .wifi(let network): return [localizer.text("consequence.wifi", network.ssid)]
        case .contact(let card): return [localizer.text("consequence.contact", card.name ?? card.organization ?? localizer.text("value.unnamedContact"))]
        case .event(let event): return [localizer.text("consequence.event", event.title ?? localizer.text("value.unnamedEvent"))]
        case .location: return [localizer.text("consequence.location")]
        case .messaging(let link): return [localizer.text("consequence.messaging", localizer.text("messaging.\(link.app.rawValue)"))]
        case .login(let login):
            return [localizer.text("consequence.login.\(login.service.rawValue)")]
        case .eSIM: return [localizer.text("consequence.eSIM")]
        case .appLink(let url):
            if url.pathExtension.lowercased() == "mobileconfig" { return [localizer.text("consequence.profile")] }
            if url.scheme?.lowercased() == "itms-services" { return [localizer.text("consequence.enterprise")] }
            if ["apk", "ipa"].contains(url.pathExtension.lowercased()) { return [localizer.text("consequence.download")] }
            if ["javascript", "data", "file"].contains(url.scheme?.lowercased() ?? "") { return [localizer.text("consequence.unsafeScheme")] }
            if let store = AppLinkParser.store(url) { return [localizer.text("consequence.store", localizer.text("store.\(store)"))] }
            return [localizer.text("consequence.appLink")]
        case .text: return [localizer.text("consequence.text")]
        }
    }

    func limitations(_ parsed: ParsedCode, embedded: EmbeddedPayloads.Result) -> [String] {
        if parsed.issues.contains(.tooLarge) { return [localizer.text("limitation.tooLarge")] }
        var keys = ["limitation.device"]
        if !parsed.issues.isEmpty { keys.append("limitation.incomplete") }
        switch parsed.payload {
        case .link: keys.append("limitation.page")
        case .payment(let payment):
            keys.append("limitation.account")
            if payment.format != .czechSPD { keys.append("limitation.bankHandoff") }
            if payment.checksum == .valid { keys.append("limitation.checksum") }
            if payment.format == .payBySquare { keys.append("limitation.payBySquare") }
            if payment.format == .czechInvoice { keys.append("limitation.invoice") }
            if payment.format == .emvMerchant { keys.append("limitation.emv") }
        case .crypto(let crypto):
            keys += ["limitation.cryptoOwner", "limitation.cryptoNetwork"]
            if crypto.network == .lightning { keys.append("limitation.lightning") }
            if crypto.network == .ethereum { keys.append("limitation.ethereum") }
            if crypto.assetContract != nil { keys.append("limitation.token") }
        case .phone, .sms: keys += ["limitation.numberOwner", "limitation.tariff"]
        case .email, .messaging, .contact: keys.append("limitation.identity")
        case .wifi: keys.append("limitation.wifi")
        case .event(let event):
            keys.append("limitation.event")
            if !event.isAllDay && event.timeZoneIdentifier == nil { keys.append("limitation.timeZone") }
        case .location: keys.append("limitation.location")
        case .login(let login):
            keys.append("limitation.login")
            if login.service == .authenticatorExport { keys.append("limitation.export") }
        case .eSIM: keys.append("limitation.eSIM")
        case .appLink: keys.append("limitation.app")
        case .text: keys.append("limitation.text")
        }
        if !embedded.links.isEmpty { keys.append("limitation.page") }
        if embedded.isTruncated { keys.append("limitation.nestedLimit") }
        return keys.uniqued(by: { $0 }).map { localizer.text($0) }
    }
}
