import Foundation

enum SPDParser {
    static func parse(_ raw: String) -> ParsedCode {
        let parts = raw.components(separatedBy: "*")
        let invoice = parts[0].uppercased() == "SID"
        var payment = PaymentRequest(format: invoice ? .czechInvoice : .czechSPD)
        var issues: Set<DecodeIssue> = []
        if parts.count < 2 || ParseSupport.trimmed(parts[1]) != "1.0" { issues.insert(.unsupported) }
        var encoded: [(String, String)] = []
        for part in parts.dropFirst(2) where !ParseSupport.trimmed(part).isEmpty {
            guard let colon = part.firstIndex(of: ":") else { issues.insert(.malformed); continue }
            let key = ParseSupport.trimmed(String(part[..<colon])).uppercased()
            let value = ParseSupport.trimmed(String(part[part.index(after: colon)...]))
            guard ParseSupport.matches(key, #"^[A-Z][A-Z0-9-]*$"#), !value.isEmpty else {
                issues.insert(.malformed)
                continue
            }
            encoded.append((key, value))
        }
        let decoded = ParseSupport.fieldMap(encoded.map { ($0.0, ParseSupport.decoded($0.1)) })
        if decoded.duplicate { issues.insert(.ambiguous) }
        let fields = decoded.fields
        payment.fields = fields
        if let account = fields["ACC"] {
            let pair = account.components(separatedBy: "+")
            payment.iban = IBAN.normalized(pair[0])
            payment.bic = pair.count > 1 ? ParseSupport.nonempty(pair[1])?.uppercased() : nil
            if pair.count > 2 { issues.insert(.malformed) }
        } else if !invoice {
            issues.insert(.malformed)
        }
        payment.alternateAccounts = (fields["ALT-ACC"] ?? "").split(separator: ",").map { ParseSupport.trimmed(String($0)) }
        if let amount = fields["AM"] {
            let negative = invoice && amount.hasPrefix("-")
            payment.amount = ParseSupport.decimal(negative ? String(amount.dropFirst()) : amount).map { negative ? -$0 : $0 }
            if payment.amount == nil || !ParseSupport.matches(amount, invoice ? #"^-?[0-9]{1,15}(?:\.[0-9]{1,2})?$"# : #"^[0-9]{1,10}(?:\.[0-9]{1,2})?$"#) {
                issues.insert(.malformed)
            }
        }
        payment.currency = fields["CC"]?.uppercased() ?? (invoice ? "CZK" : nil)
        payment.recipientName = ParseSupport.nonempty(fields["RN"])
        payment.message = fields["MSG"]
        payment.reference = fields["RF"]
        payment.variableSymbol = fields[invoice ? "VS" : "X-VS"]
        payment.specificSymbol = fields["X-SS"]
        payment.constantSymbol = fields["X-KS"]
        payment.paymentID = fields["X-ID"] ?? fields["ID"]
        payment.paymentURL = fields["X-URL"]
        payment.dueDate = ParseSupport.dateComponents(fields["DT"])
        if fields["DT"] != nil && payment.dueDate == nil { issues.insert(.malformed) }
        if let type = fields["PT"] { payment.isInstant = type.uppercased() == "IP" }
        payment.notificationType = fields["NT"]?.uppercased()
        payment.notificationAddress = fields["NTA"] ?? fields["NN"]
        if let address = fields["NTA"], let alias = fields["NN"], address != alias { issues.insert(.ambiguous) }
        payment.retryDays = fields["X-PER"].flatMap(Int.init)
        if let retry = fields["X-PER"], !(0...30).contains(Int(retry) ?? -1) { issues.insert(.malformed) }
        if let selfPayment = fields["X-SELF"] { payment.isSelfPayment = ["1", "TRUE", "Y"].contains(selfPayment.uppercased()) }
        if invoice && (fields["ID"] == nil || ParseSupport.dateComponents(fields["DD"]) == nil || payment.amount == nil) {
            issues.insert(.malformed)
        }
        if let checksum = fields["CRC32"] {
            let attributes = encoded.filter { $0.0 != "CRC32" }.sorted {
                $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0
            }.map { "\($0.0):\($0.1)" }.joined(separator: "*")
            let canonical = "\(invoice ? "SID" : "SPD")*1.0*" + attributes + (invoice ? "*" : "")
            payment.checksum = ParseSupport.matches(checksum, #"^[a-fA-F0-9]{8}$"#)
                && UInt32(checksum, radix: 16) == Checksums.crc32(canonical.utf8) ? .valid : .invalid
        }
        PaymentParser.enrich(&payment)
        issues.formUnion(PaymentParser.validate(payment))
        return ParsedCode(payload: .payment(payment), issues: issues)
    }
}
