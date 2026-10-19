import Foundation

struct Localizer: Sendable {
    let locale: Locale
    var isCzech: Bool { locale.language.languageCode?.identifier == "cs" }

    private struct Catalog: Decodable, Sendable {
        struct Entry: Decodable, Sendable {
            struct Translation: Decodable, Sendable {
                struct Unit: Decodable, Sendable { let value: String }
                let stringUnit: Unit
            }
            let localizations: [String: Translation]
        }
        let strings: [String: Entry]
    }

    private static let catalog = ResourceData.load("Localizable", extension: "xcstrings", as: Catalog.self)

    func text(_ key: String, _ values: String...) -> String {
        format(key, values: values)
    }

    func format(_ key: String, values: [String]) -> String {
        guard let entry = Self.catalog.strings[key],
              let template = entry.localizations[isCzech ? "cs" : "en"]?.stringUnit.value else {
            preconditionFailure("Missing localization: \(key)")
        }
        // A single pass prevents scanned text containing a placeholder from changing another value.
        return template.components(separatedBy: "%@").enumerated().map { index, part in
            (index > 0 && index <= values.count ? display(values[index - 1]) : "") + part
        }.joined()
    }

    func display(_ value: String) -> String {
        let cleaned = value.unicodeScalars.map { scalar -> Character in
            let number = scalar.value
            if number < 32 || (0x7F...0x9F).contains(number) || (0x202A...0x202E).contains(number)
                || (0x2066...0x2069).contains(number) || number == 0x200E || number == 0x200F {
                return " "
            }
            return Character(scalar)
        }
        return String(cleaned.prefix(2_048)) + (cleaned.count > 2_048 ? "…" : "")
    }

    func amount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 38
        let number = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
        return isCzech && currency == "CZK" ? text("amount.czk", number) : "\(currency) \(number)"
    }

    func date(_ value: Date, allDay: Bool = false, timeZone: TimeZone = TimeZone.gmt) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = allDay ? .none : .short
        return formatter.string(from: value)
    }

    func dueDate(_ parts: DateComponents) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.gmt
        return calendar.date(from: parts).map { date($0, allDay: true) }
    }
}
