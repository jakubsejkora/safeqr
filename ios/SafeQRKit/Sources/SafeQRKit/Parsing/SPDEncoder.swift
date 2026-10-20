import Foundation

/// Builds a QR Platba containing only the reviewed transfer details.
public enum SPDEncoder {
    public enum EncodingError: Error, Sendable {
        case unsupportedFormat, invalidAccount, invalidAmount, invalidField
    }

    /// Excludes all extensions except VS, SS and KS. Never rounds or truncates payment details.
    public static func encode(_ payment: PaymentRequest) throws -> String {
        guard payment.format == .czechSPD else { throw EncodingError.unsupportedFormat }
        guard let account = payment.iban, IBAN.isValid(account) else { throw EncodingError.invalidAccount }
        var accountValue = IBAN.normalized(account)
        if let bic = payment.bic {
            let bic = ParseSupport.trimmed(bic).uppercased()
            guard ParseSupport.matches(bic, #"^[A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?$"#) else {
                throw EncodingError.invalidField
            }
            accountValue += "+" + bic
        }
        var fields = ["SPD", "1.0", "ACC:" + accountValue]
        if var amount = payment.amount {
            guard !amount.isNaN, amount > 0, amount <= Decimal(9_999_999) + Decimal(99) / 100 else {
                throw EncodingError.invalidAmount
            }
            var rounded = Decimal()
            NSDecimalRound(&rounded, &amount, 2, .plain)
            guard rounded == amount else { throw EncodingError.invalidAmount }
            fields.append("AM:" + NSDecimalString(&rounded, Locale(identifier: "en_US_POSIX")))
        }
        if let currency = payment.currency {
            let currency = ParseSupport.trimmed(currency).uppercased()
            guard ParseSupport.matches(currency, #"^[A-Z]{3}$"#) else { throw EncodingError.invalidField }
            fields.append("CC:" + currency)
        }
        for (key, value) in [("X-VS", payment.variableSymbol), ("X-SS", payment.specificSymbol),
                             ("X-KS", payment.constantSymbol)] {
            guard let value else { continue }
            guard ParseSupport.matches(value, #"^[0-9]{1,10}$"#) else { throw EncodingError.invalidField }
            fields.append(key + ":" + value)
        }
        for (key, value, limit) in [("MSG", payment.message, 60), ("RN", payment.recipientName, 35)] {
            guard let value = ParseSupport.nonempty(value) else { continue }
            guard value.count <= limit, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw EncodingError.invalidField
            }
            fields.append(key + ":" + escaped(value))
        }
        if let due = payment.dueDate {
            guard let year = due.year, let month = due.month, let day = due.day, (1...9999).contains(year) else {
                throw EncodingError.invalidField
            }
            let date = String(format: "%04d%02d%02d", year, month, day)
            guard ParseSupport.dateComponents(date) != nil else { throw EncodingError.invalidField }
            fields.append("DT:" + date)
        }
        return fields.joined(separator: "*")
    }

    private static func escaped(_ value: String) -> String {
        value.utf8.map { byte in
            if (0x20...0x7E).contains(byte), byte != 0x25, byte != 0x2A {
                return String(UnicodeScalar(byte))
            }
            return String(format: "%%%02X", byte)
        }.joined()
    }
}
