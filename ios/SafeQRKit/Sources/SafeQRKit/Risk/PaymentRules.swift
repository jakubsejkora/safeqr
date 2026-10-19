import Foundation

enum PaymentRules {
    static func evaluate(_ payment: PaymentRequest) -> [RiskSignal] {
        var rules: [RiskSignal] = []
        if payment.format == .payBySquare { return [RiskSignal("payment.payBySquare", 40, floor: 30)] }
        if payment.checksum == .invalid { rules.append(RiskSignal("payment.checksum", 80, floor: 80)) }
        if let iban = payment.iban {
            if !IBAN.isValid(iban) { rules.append(RiskSignal("payment.invalidIBAN", 80, floor: 80)) }
            if [.czechSPD, .czechInvoice].contains(payment.format) && !iban.hasPrefix("CZ") {
                rules.append(RiskSignal("payment.foreignAccount", 30))
            }
            if iban.hasPrefix("CZ") && payment.bankName == nil { rules.append(RiskSignal("payment.unknownBank", 35)) }
            if let currency = payment.currency {
                let country = String(iban.prefix(2))
                let ordinary: [String: Set<String>] = ["CZ": ["CZK", "EUR"], "CH": ["CHF", "EUR"], "LI": ["CHF", "EUR"], "GB": ["GBP", "EUR"],
                                                       "PL": ["PLN", "EUR"], "HU": ["HUF", "EUR"], "SE": ["SEK", "EUR"], "DK": ["DKK", "EUR"], "NO": ["NOK", "EUR"]]
                let euroCountries: Set<String> = ["AT", "BE", "CY", "DE", "EE", "ES", "FI", "FR", "GR", "HR", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PT", "SI", "SK"]
                if (currency == "CZK" && country != "CZ") || ordinary[country].map({ !$0.contains(currency) }) == true
                    || (euroCountries.contains(country) && currency != "EUR") {
                    rules.append(RiskSignal("payment.currencyCountry", 15))
                }
            }
        }
        for alternate in payment.alternateAccounts {
            let iban = IBAN.normalized(String(alternate.split(separator: "+", omittingEmptySubsequences: false)[0]))
            if !IBAN.isValid(iban) { rules.append(RiskSignal("payment.invalidIBAN", 80, floor: 80)) }
            if [.czechSPD, .czechInvoice].contains(payment.format), !iban.hasPrefix("CZ") { rules.append(RiskSignal("payment.foreignAccount", 30)) }
            if iban.hasPrefix("CZ"), !ResourceData.banks.contains(where: { $0.code == String(iban.dropFirst(4).prefix(4)) }) {
                rules.append(RiskSignal("payment.unknownBank", 35))
            }
        }
        if !payment.alternateAccounts.isEmpty { rules.append(RiskSignal("payment.alternateAccounts", 15)) }
        if payment.isInstant == true { rules.append(RiskSignal("payment.instant", 10)) }
        if payment.recipientName == nil { rules.append(RiskSignal("payment.missingRecipient", 10)) }
        else if let name = payment.recipientName, name.count < 2 || name.allSatisfy({ $0.isNumber || $0.isWhitespace }) || LinkParser.containsControls(name) {
            rules.append(RiskSignal("payment.oddRecipient", 30))
        }
        if let amount = payment.amount {
            let thresholds: [String: Decimal] = ["CZK": 100_000, "EUR": 5_000, "USD": 5_000, "GBP": 4_000, "CHF": 5_000,
                                                 "JPY": 1_000_000, "INR": 500_000, "PLN": 20_000, "HUF": 2_000_000]
            if let threshold = payment.currency.flatMap({ thresholds[$0] }), amount >= threshold { rules.append(RiskSignal("payment.highAmount", 30)) }
            if amount <= 0 && payment.format != .czechInvoice { rules.append(RiskSignal("payment.invalidAmount", 40, floor: 30)) }
        } else { rules.append(RiskSignal("payment.noAmount", 10)) }
        if payment.currency == nil { rules.append(RiskSignal("payment.noCurrency", 20)) }
        if payment.notificationAddress != nil { rules.append(RiskSignal("payment.notification", 10)) }
        if let days = payment.retryDays, days > 0 {
            rules.append(RiskSignal("payment.retry", 10, arguments: [String(days)],
                                    detailKey: days == 1 ? "finding.payment.retry.one" : "finding.payment.retry.detail"))
        }
        return rules
    }
}
