import Foundation

enum PayBySquareParser {
    static func recognizes(_ raw: String) -> Bool {
        guard (20...12_000).contains(raw.utf8.count), ParseSupport.matches(raw, #"^[0-9A-Va-v]+$"#),
              let header = decodeHeader(raw) else { return false }
        // The first two bytes identify PAY (0), version 0 and document type 0.
        return header[0] == 0 && header[1] == 0 && (header[2] != 0 || header[3] != 0)
    }

    static func parse() -> ParsedCode {
        ParsedCode(payload: .payment(PaymentRequest(format: .payBySquare)), issues: [.unsupported])
    }

    private static func decodeHeader(_ value: String) -> [UInt8]? {
        var buffer: UInt32 = 0
        var bits = 0
        var bytes: [UInt8] = []
        for byte in value.uppercased().prefix(7).utf8 {
            let digit = byte <= 57 ? byte - 48 : byte - 65 + 10
            guard digit < 32 else { return nil }
            buffer = (buffer << 5) | UInt32(digit)
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> bits) & 255))
            }
        }
        return bytes.count == 4 ? bytes : nil
    }
}
