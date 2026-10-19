import Foundation

enum SwissPaymentParser {
    static func parse(_ raw: String) -> ParsedCode {
        let lines = ParseSupport.lines(raw).map(ParseSupport.trimmed)
        func field(_ index: Int) -> String? { index < lines.count ? ParseSupport.nonempty(lines[index]) : nil }
        var payment = PaymentRequest(format: .swissQRBill)
        var issues: Set<DecodeIssue> = []
        if field(1) != "0200" { issues.insert(.unsupported) }
        payment.iban = field(3).map(IBAN.normalized)
        payment.recipientName = field(5)
        payment.amount = ParseSupport.decimal(field(18))
        payment.currency = field(19)?.uppercased()
        payment.reference = field(28)
        payment.message = field(29)
        payment.fields["addressType"] = field(4)
        payment.fields["recipientCountry"] = field(10)
        payment.fields["referenceType"] = field(27)
        payment.fields["billingInformation"] = field(31)
        for (index, value) in lines.dropFirst(32).prefix(2).enumerated() {
            payment.fields["alternative\(index + 1)"] = ParseSupport.nonempty(value)
        }
        if field(2) != "1" || field(30)?.uppercased() != "EPD" || payment.iban == nil
            || payment.recipientName == nil || !["S", "K"].contains(field(4) ?? "")
            || !["CHF", "EUR"].contains(payment.currency ?? "")
            || !["QRR", "SCOR", "NON"].contains(field(27) ?? "")
            || (field(18) != nil && payment.amount == nil) { issues.insert(.malformed) }
        if let iban = payment.iban, !iban.hasPrefix("CH") && !iban.hasPrefix("LI") { issues.insert(.malformed) }
        if field(27) == "QRR" {
            payment.checksum = validQRReference(field(28) ?? "") ? .valid : .invalid
            if let iban = payment.iban {
                let iid = Int(iban.dropFirst(4).prefix(5)) ?? 0
                if !(30_000...31_999).contains(iid) { issues.insert(.malformed) }
            }
        } else if field(27) == "SCOR" {
            payment.checksum = validCreditorReference(field(28) ?? "") ? .valid : .invalid
        } else if field(27) == "NON", field(28) != nil { issues.insert(.malformed) }
        if let iban = payment.iban, (30_000...31_999).contains(Int(iban.dropFirst(4).prefix(5)) ?? 0), field(27) != "QRR" { issues.insert(.malformed) }
        issues.formUnion(PaymentParser.validate(payment))
        PaymentParser.enrich(&payment)
        return ParsedCode(payload: .payment(payment), issues: issues)
    }

    static func validQRReference(_ value: String) -> Bool {
        guard ParseSupport.matches(value, #"^[0-9]{27}$"#) else { return false }
        let table = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5]
        var carry = 0
        for digit in value.dropLast().utf8 { carry = table[(carry + Int(digit - 48)) % 10] }
        return value.last?.wholeNumberValue == (10 - carry) % 10
    }

    static func validCreditorReference(_ value: String) -> Bool {
        let value = IBAN.normalized(value)
        guard ParseSupport.matches(value, #"^RF[0-9]{2}[A-Z0-9]{1,21}$"#) else { return false }
        var remainder = 0
        for byte in (value.dropFirst(4) + value.prefix(4)).utf8 {
            let number = byte >= 65 ? Int(byte) - 55 : Int(byte) - 48
            remainder = (remainder * (number >= 10 ? 100 : 10) + number) % 97
        }
        return remainder == 1
    }
}
