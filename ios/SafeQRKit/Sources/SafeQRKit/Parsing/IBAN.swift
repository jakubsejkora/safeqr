import Foundation

/// Syntax and mod-97 validation; a valid IBAN does not establish account ownership.
public enum IBAN {
    /// Removes presentation spaces and makes letters uppercase.
    public static func normalized(_ value: String) -> String {
        value.filter { !$0.isWhitespace }.uppercased()
    }

    public static func isValid(_ value: String) -> Bool {
        let value = normalized(value)
        guard (15...34).contains(value.utf8.count),
              ParseSupport.matches(value, #"^[A-Z]{2}[0-9]{2}[A-Z0-9]+$"#),
              lengths[String(value.prefix(2))] == value.utf8.count else { return false }
        if ["CZ", "SK"].contains(String(value.prefix(2))), !ParseSupport.matches(String(value.dropFirst(4)), #"^[0-9]{20}$"#) { return false }
        var remainder = 0
        for byte in (value.dropFirst(4) + value.prefix(4)).utf8 {
            let number = byte >= 65 ? Int(byte) - 55 : Int(byte) - 48
            remainder = (remainder * (number >= 10 ? 100 : 10) + number) % 97
        }
        return remainder == 1
    }

    public static func czechDomesticAccount(_ value: String) -> String? {
        let value = normalized(value)
        guard value.hasPrefix("CZ"), isValid(value),
              ParseSupport.matches(String(value.dropFirst(4)), #"^[0-9]{20}$"#) else { return nil }
        let code = String(value.dropFirst(4).prefix(4))
        let prefix = String(value.dropFirst(8).prefix(6).drop(while: { $0 == "0" }))
        let account = String(value.suffix(10).drop(while: { $0 == "0" }))
        return (prefix.isEmpty ? "" : prefix + "-") + (account.isEmpty ? "0" : account) + "/" + code
    }

    // Country lengths prevent a mathematically valid checksum from accepting a truncated account.
    private static let lengths: [String: Int] = [
        "AD": 24, "AE": 23, "AL": 28, "AT": 20, "AZ": 28, "BA": 20, "BE": 16, "BG": 22,
        "BH": 22, "BI": 27, "BR": 29, "BY": 28, "CH": 21, "CR": 22, "CY": 28, "CZ": 24,
        "DE": 22, "DJ": 27, "DK": 18, "DO": 28, "EE": 20, "EG": 29, "ES": 24, "FI": 18,
        "FK": 18, "FO": 18, "FR": 27, "GB": 22, "GE": 22, "GI": 23, "GL": 18, "GR": 27,
        "GT": 28, "HN": 28, "HR": 21, "HU": 28, "IE": 22, "IL": 23, "IQ": 23, "IS": 26,
        "IT": 27, "JO": 30, "KW": 30, "KZ": 20, "LB": 28, "LC": 32, "LI": 21, "LT": 20,
        "LU": 20, "LV": 21, "LY": 25, "MC": 27, "MD": 24, "ME": 22, "MK": 19, "MN": 20,
        "MR": 27, "MT": 31, "MU": 30, "NI": 28, "NL": 18, "NO": 15, "OM": 23, "PK": 24,
        "PL": 28, "PS": 29, "PT": 25, "QA": 29, "RO": 24, "RS": 22, "RU": 33, "SA": 24,
        "SC": 31, "SD": 18, "SE": 24, "SI": 19, "SK": 24, "SM": 27, "SO": 23, "ST": 25,
        "SV": 28, "TL": 23, "TN": 24, "TR": 26, "UA": 29, "VA": 22, "VG": 24, "XK": 20, "YE": 30,
    ]
}
