import Foundation

struct ContentBuilder {
    let localizer: Localizer

    func build(_ payload: Payload, raw: String, embedded: EmbeddedPayloads.Result) -> CodeContent {
        var facts: [Fact] = []
        func add(_ id: String, _ value: String?, emphasis: Fact.Emphasis = .normal) {
            guard let value = ParseSupport.nonempty(value) else { return }
            facts.append(Fact(id: id, label: localizer.text("fact.\(id.split(separator: ".")[0])"),
                              value: localizer.display(value), emphasis: emphasis))
        }
        switch payload {
        case .link(let url), .appLink(let url):
            add("domain", url.host(percentEncoded: false), emphasis: .primary)
            add("address", url.absoluteString)
            if raw != url.absoluteString { add("original", raw) }
        case .payment(let payment):
            add("amount", payment.amount.map { localizer.amount($0, currency: payment.currency ?? localizer.text("value.currencyUnknown")) }, emphasis: .primary)
            add("account", account(payment), emphasis: .primary)
            add("bank", payment.bankName)
            add("recipient", payment.recipientName)
            add("format", localizer.text("format.\(payment.format.rawValue)"))
            add("bic", payment.bic)
            add("variableSymbol", payment.variableSymbol)
            add("specificSymbol", payment.specificSymbol)
            add("constantSymbol", payment.constantSymbol)
            add("reference", payment.reference)
            add("paymentID", payment.paymentID)
            add("dueDate", payment.dueDate.flatMap(localizer.dueDate))
            add("message", payment.message)
            if let instant = payment.isInstant { add("instant", localizer.text(instant ? "value.yes" : "value.no")) }
            for (index, alternate) in payment.alternateAccounts.enumerated() { add("alternate.\(index)", alternate) }
            add("paymentURL", payment.paymentURL, emphasis: .warning)
            add("notification", payment.notificationAddress)
            add("retryDays", payment.retryDays.map(String.init))
            if let own = payment.isSelfPayment { add("selfPayment", localizer.text(own ? "value.yes" : "value.no")) }
            if payment.checksum != .notPresent { add("checksum", localizer.text("checksum.\(payment.checksum.rawValue)"), emphasis: payment.checksum == .invalid ? .warning : .normal) }
        case .crypto(let request):
            add("network", localizer.text("network.\(request.network.rawValue)"))
            add("account", request.address, emphasis: .primary)
            let unit = request.amountUnit.map { ["token", "baseUnits"].contains($0) ? localizer.text("unit.\($0)") : $0 } ?? ""
            add("amount", request.amount.map { localizer.amount($0, currency: unit) }, emphasis: .primary)
            add("asset", request.assetContract)
            add("chain", request.chainID)
            add("operation", request.function)
            add("recipient", request.label)
            add("message", request.message)
        case .sms(let recipient, let body):
            add("recipient", recipient, emphasis: .primary)
            add("message", body)
            if let charge = PhoneRules.charge(recipient, sms: true), let amount = charge.amount {
                add("price", localizer.text("price.\(charge.unit)", localizer.amount(Decimal(amount), currency: "CZK")), emphasis: .warning)
            }
        case .phone(let number):
            add("phone", number, emphasis: .primary)
            if let charge = PhoneRules.charge(number, sms: false), let amount = charge.amount {
                add("price", localizer.text("price.\(charge.unit)", localizer.amount(Decimal(amount), currency: "CZK")), emphasis: .warning)
            }
        case .email(let recipient, let subject, let body):
            add("recipient", recipient, emphasis: .primary)
            add("subject", subject)
            add("message", body)
        case .wifi(let network):
            add("networkName", network.ssid, emphasis: .primary)
            add("security", localizer.text("wifi.\(network.security.rawValue)"))
            if network.password != nil { add("password", localizer.text("value.hidden")) }
            add("hiddenNetwork", localizer.text(network.isHidden ? "value.yes" : "value.no"))
        case .contact(let card):
            add("name", card.name, emphasis: .primary)
            add("organization", card.organization)
            for (index, phone) in card.phoneNumbers.enumerated() { add("phone.\(index)", phone) }
            for (index, email) in card.emails.enumerated() { add("email.\(index)", email) }
            for (index, url) in card.urls.enumerated() { add("address.\(index)", url) }
            add("note", card.note)
        case .event(let event):
            add("name", event.title, emphasis: .primary)
            let zone = event.timeZoneIdentifier.flatMap { identifier in TimeZone.knownTimeZoneIdentifiers.first { $0.uppercased() == identifier } }
                .flatMap(TimeZone.init(identifier:)) ?? TimeZone(secondsFromGMT: 0)!
            add("start", event.start.map { localizer.date($0, allDay: event.isAllDay, timeZone: zone) })
            add("end", event.end.map { localizer.date($0, allDay: event.isAllDay, timeZone: zone) })
            add("timeZone", event.isAllDay ? nil : event.timeZoneIdentifier)
            add("place", event.location)
            add("note", event.description)
            add("address", event.url)
        case .location(let latitude, let longitude, let query):
            add("coordinates", "\(latitude), \(longitude)", emphasis: .primary)
            add("place", query)
        case .messaging(let link):
            add("app", localizer.text("messaging.\(link.app.rawValue)"))
            add("recipient", link.recipient, emphasis: .primary)
            add("message", link.prefilledText)
        case .login(let login):
            add("service", localizer.text("service.\(login.service.rawValue)"), emphasis: .primary)
            add("issuer", login.issuer)
            add("account", login.account)
            add("accountCount", login.accountCount.map(String.init))
            add("batchSize", login.batchSize.map(String.init))
            add("secret", localizer.text("value.hidden"), emphasis: .warning)
        case .eSIM(let activation):
            add("provider", activation.smdpAddress, emphasis: .primary)
            add("secret", localizer.text("value.hidden"), emphasis: .warning)
            add("confirmationCode", localizer.text(activation.requiresConfirmationCode ? "value.required" : "value.notSpecified"))
        case .text(let text): add("text", text)
        }
        for (index, url) in embedded.links.enumerated() where !facts.contains(where: { $0.value == url.absoluteString }) {
            add("embeddedLink.\(index)", url.absoluteString, emphasis: .warning)
        }
        for (index, code) in embedded.codes.enumerated() {
            add("embeddedContent.\(index)", summary(code.payload), emphasis: .warning)
        }
        return CodeContent(kind: payload.kind, payload: payload, title: title(payload), summary: summary(payload), facts: facts)
    }

    func title(_ payload: Payload) -> String {
        if case .payment(let payment) = payload, payment.format == .czechInvoice { return localizer.text("title.invoice") }
        return localizer.text("title.\(payload.kind.rawValue)")
    }

    func summary(_ payload: Payload) -> String {
        switch payload {
        case .link(let url): localizer.text("summary.link", url.host(percentEncoded: false) ?? "")
        case .payment(let payment) where payment.format == .payBySquare: localizer.text("summary.payBySquare")
        case .payment(let payment) where payment.format == .czechInvoice: localizer.text("summary.invoice")
        case .login(let login): localizer.text("summary.login.\(login.service.rawValue)")
        case .appLink(let url): appSummary(url)
        default: localizer.text("summary.\(payload.kind.rawValue)")
        }
    }

    private func appSummary(_ url: URL) -> String {
        if url.pathExtension.lowercased() == "mobileconfig" { return localizer.text("summary.profile") }
        if url.scheme?.lowercased() == "itms-services" { return localizer.text("summary.enterprise") }
        if ["apk", "ipa"].contains(url.pathExtension.lowercased()) { return localizer.text("summary.download") }
        if let store = AppLinkParser.store(url) { return localizer.text("summary.store", localizer.text("store.\(store)")) }
        return localizer.text("summary.appLink")
    }

    func account(_ payment: PaymentRequest) -> String? {
        if let domestic = payment.domesticAccount { return domestic }
        if let iban = payment.iban {
            let characters = Array(iban)
            return stride(from: 0, to: characters.count, by: 4).map { String(characters[$0..<min($0 + 4, characters.count)]) }.joined(separator: " ")
        }
        return payment.payeeIdentifier
    }
}
