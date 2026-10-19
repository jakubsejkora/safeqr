import Foundation

enum AuthenticatorExportParser {
    struct Field {
        let number: UInt64
        let integer: UInt64?
        let bytes: [UInt8]?
    }

    static func parse(_ raw: String) -> ParsedCode {
        var login = LoginCode(service: .authenticatorExport)
        let query = ParseSupport.query(raw)
        guard var base64 = query.fields["data"] else { return ParsedCode(payload: .login(login), issues: [.malformed]) }
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), let fields = decode(Array(data)) else {
            return ParsedCode(payload: .login(login), issues: [.malformed])
        }
        let accounts = fields.filter { $0.number == 1 }
        guard accounts.allSatisfy({ field in
            guard let bytes = field.bytes, let account = decode(bytes) else { return false }
            return account.contains { $0.number == 1 && $0.bytes?.isEmpty == false }
        }) else { return ParsedCode(payload: .login(login), issues: [.malformed]) }
        login.accountCount = accounts.count
        if let size = fields.first(where: { $0.number == 3 })?.integer, size <= 1_000 { login.batchSize = Int(size) }
        var issues: Set<DecodeIssue> = query.duplicate ? [.ambiguous] : []
        if accounts.isEmpty { issues.insert(.malformed) }
        if let version = fields.first(where: { $0.number == 2 })?.integer, version > 1 { issues.insert(.unsupported) }
        return ParsedCode(payload: .login(login), issues: issues)
    }

    static func decode(_ bytes: [UInt8]) -> [Field]? {
        var cursor = 0
        var fields: [Field] = []
        func varint() -> UInt64? {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard cursor < bytes.count else { return nil }
                let byte = bytes[cursor]
                cursor += 1
                if shift == 63 && byte > 1 { return nil }
                value |= UInt64(byte & 127) << shift
                if byte & 128 == 0 { return value }
            }
            return nil
        }
        while cursor < bytes.count {
            guard fields.count < 2_048, let tag = varint(), tag >> 3 > 0 else { return nil }
            switch tag & 7 {
            case 0:
                guard let value = varint() else { return nil }
                fields.append(Field(number: tag >> 3, integer: value, bytes: nil))
            case 2:
                guard let count = varint(), count <= UInt64(bytes.count - cursor) else { return nil }
                fields.append(Field(number: tag >> 3, integer: nil, bytes: Array(bytes[cursor..<cursor + Int(count)])))
                cursor += Int(count)
            case 1, 5:
                let count = tag & 7 == 1 ? 8 : 4
                guard count <= bytes.count - cursor else { return nil }
                cursor += count
                fields.append(Field(number: tag >> 3, integer: nil, bytes: nil))
            default: return nil
            }
        }
        return fields
    }
}
