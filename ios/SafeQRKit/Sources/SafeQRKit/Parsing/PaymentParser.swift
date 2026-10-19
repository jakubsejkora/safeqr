import Foundation

enum PaymentParser {
    static func parse(_ raw: String) -> ParsedCode? {
        let upper = raw.uppercased()
        if upper.hasPrefix("SPD*") || upper.hasPrefix("SID*") { return SPDParser.parse(raw) }
        let firstLine = ParseSupport.lines(raw).first?.uppercased()
        if firstLine == "BCD" { return EPCParser.parse(raw) }
        if firstLine == "SPC" { return SwissPaymentParser.parse(raw) }
        if raw.hasPrefix("000201") { return EMVParser.parse(raw) }
        if ParseSupport.scheme(raw) == "upi" { return UPIParser.parse(raw) }
        if PayBySquareParser.recognizes(raw) { return PayBySquareParser.parse() }
        return nil
    }

    static func enrich(_ payment: inout PaymentRequest) {
        guard let iban = payment.iban, iban.hasPrefix("CZ"), iban.count == 24 else { return }
        let code = String(iban.dropFirst(4).prefix(4))
        payment.bankCode = code
        payment.domesticAccount = IBAN.czechDomesticAccount(iban)
        payment.bankName = ResourceData.banks.first { $0.code == code }?.name
    }

    static func validate(_ payment: PaymentRequest) -> Set<DecodeIssue> {
        var issues: Set<DecodeIssue> = []
        if let bic = payment.bic, !ParseSupport.matches(bic, #"^[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?$"#) { issues.insert(.malformed) }
        if let currency = payment.currency, !ParseSupport.matches(currency, #"^[A-Z]{3}$"#) { issues.insert(.malformed) }
        return issues
    }
}
