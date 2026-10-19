import Foundation

enum EPCParser {
    static func parse(_ raw: String) -> ParsedCode {
        let lines = ParseSupport.lines(raw).map(ParseSupport.trimmed)
        func field(_ index: Int) -> String? { index < lines.count ? ParseSupport.nonempty(lines[index]) : nil }
        var payment = PaymentRequest(format: .sepaEPC)
        var issues: Set<DecodeIssue> = []
        if !["001", "002"].contains(field(1) ?? "") { issues.insert(.unsupported) }
        if field(3)?.uppercased() != "SCT" || !(1...8).contains(Int(field(2) ?? "") ?? 0) { issues.insert(.malformed) }
        payment.bic = field(4)?.uppercased()
        payment.recipientName = field(5)
        payment.iban = field(6).map(IBAN.normalized)
        payment.currency = "EUR"
        if let amount = field(7) {
            if amount.uppercased().hasPrefix("EUR") { payment.amount = ParseSupport.decimal(String(amount.dropFirst(3))) }
            if payment.amount == nil || !ParseSupport.matches(String(amount.dropFirst(3)), #"^[0-9]+(?:\.[0-9]{1,2})?$"#) { issues.insert(.malformed) }
        }
        payment.reference = field(9)
        payment.message = field(10)
        for (index, name) in [(1, "version"), (2, "encoding"), (8, "purpose"), (11, "information")] {
            payment.fields[name] = field(index)
        }
        if lines.count < 7 || payment.iban == nil || payment.recipientName == nil
            || (field(1) == "001" && payment.bic == nil) { issues.insert(.malformed) }
        if field(9) != nil && field(10) != nil { issues.insert(.ambiguous) }
        if let reference = payment.reference, !SwissPaymentParser.validCreditorReference(reference) { payment.checksum = .invalid }
        if lines.dropFirst(12).contains(where: { !$0.isEmpty }) || raw.utf8.count > 331 { issues.insert(.malformed) }
        PaymentParser.enrich(&payment)
        issues.formUnion(PaymentParser.validate(payment))
        return ParsedCode(payload: .payment(payment), issues: issues)
    }
}
