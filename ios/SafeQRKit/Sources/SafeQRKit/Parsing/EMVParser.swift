import Foundation

enum EMVParser {
    struct Field {
        let tag: String
        let value: String
        let headerEnd: Int
    }

    static func fields(_ raw: String) -> [Field]? {
        let characters = Array(raw.unicodeScalars)
        var fields: [Field] = []
        var cursor = 0
        while cursor < characters.count {
            guard cursor + 4 <= characters.count else { return nil }
            let header = String(String.UnicodeScalarView(characters[cursor..<cursor + 4]))
            guard ParseSupport.matches(header, #"^[0-9]{4}$"#), let count = Int(header.suffix(2)),
                  count > 0, cursor + 4 + count <= characters.count else { return nil }
            fields.append(Field(tag: String(header.prefix(2)),
                                value: String(String.UnicodeScalarView(characters[cursor + 4..<cursor + 4 + count])),
                                headerEnd: cursor + 4))
            cursor += 4 + count
        }
        return fields
    }

    static func parse(_ raw: String) -> ParsedCode {
        var payment = PaymentRequest(format: .emvMerchant)
        guard let items = fields(raw) else {
            payment.checksum = .invalid
            return ParsedCode(payload: .payment(payment), issues: [.malformed])
        }
        let map = ParseSupport.fieldMap(items.map { ($0.tag, $0.value) })
        payment.fields = map.fields
        var issues: Set<DecodeIssue> = map.duplicate ? [.ambiguous] : []
        payment.recipientName = map.fields["59"]
        payment.amount = ParseSupport.decimal(map.fields["54"])
        payment.currency = map.fields["53"].flatMap { ResourceData.currencies[$0] }
        payment.payeeIdentifier = items.first { (2...51).contains(Int($0.tag) ?? -1) }?.value
        if let additional = map.fields["62"], let nested = fields(additional) {
            let nestedMap = ParseSupport.fieldMap(nested.map { ($0.tag, $0.value) })
            payment.reference = nestedMap.fields["05"] ?? nestedMap.fields["01"]
            payment.message = nestedMap.fields["08"]
            if nestedMap.duplicate { issues.insert(.ambiguous) }
        }
        for item in items where (26...51).contains(Int(item.tag) ?? -1) || ["62", "64"].contains(item.tag) {
            if let nested = fields(item.value) {
                if Set(nested.map(\.tag)).count != nested.count { issues.insert(.ambiguous) }
                if (26...51).contains(Int(item.tag) ?? -1), !nested.contains(where: { $0.tag == "00" }) { issues.insert(.malformed) }
            } else { issues.insert(.malformed) }
        }
        if items.first?.tag != "00" || map.fields["00"] != "01" || map.fields["52"] == nil
            || map.fields["53"] == nil || map.fields["58"] == nil || map.fields["59"] == nil
            || map.fields["60"] == nil || payment.payeeIdentifier == nil
            || (map.fields["54"] != nil && payment.amount == nil) { issues.insert(.malformed) }
        if !ParseSupport.matches(map.fields["52"] ?? "", #"^[0-9]{4}$"#)
            || !ParseSupport.matches(map.fields["53"] ?? "", #"^[0-9]{3}$"#)
            || !ParseSupport.matches(map.fields["58"] ?? "", #"^[A-Z]{2}$"#)
            || map.fields["01"].map({ !["11", "12"].contains($0) }) == true { issues.insert(.malformed) }
        if payment.currency == nil { issues.insert(.unsupported) }
        if let crc = items.last, crc.tag == "63", ParseSupport.matches(crc.value, #"^[a-fA-F0-9]{4}$"#) {
            let input = String(String.UnicodeScalarView(Array(raw.unicodeScalars).prefix(crc.headerEnd)))
            payment.checksum = UInt16(crc.value, radix: 16) == Checksums.crc16(input.utf8) ? .valid : .invalid
        } else {
            payment.checksum = .invalid
        }
        return ParsedCode(payload: .payment(payment), issues: issues)
    }

}
