import Foundation

enum UPIParser {
    static func parse(_ raw: String) -> ParsedCode {
        let query = ParseSupport.query(raw)
        var payment = PaymentRequest(format: .upi)
        payment.fields = query.fields
        payment.payeeIdentifier = query.fields["pa"]
        payment.recipientName = query.fields["pn"]
        payment.amount = ParseSupport.decimal(query.fields["am"])
        payment.currency = query.fields["cu"]?.uppercased() ?? "INR"
        payment.message = query.fields["tn"]
        payment.reference = query.fields["tr"]
        payment.paymentURL = query.fields["url"]
        var issues: Set<DecodeIssue> = query.duplicate ? [.ambiguous] : []
        if URLComponents(string: raw)?.host?.lowercased() != "pay"
            || !ParseSupport.matches(payment.payeeIdentifier ?? "", #"^[^\s@]+@[^\s@]+$"#)
            || (query.fields["am"] != nil && payment.amount == nil) { issues.insert(.malformed) }
        if payment.currency != "INR" { issues.insert(.unsupported) }
        issues.formUnion(PaymentParser.validate(payment))
        return ParsedCode(payload: .payment(payment), issues: issues)
    }
}
