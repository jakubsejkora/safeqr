import Foundation

struct ParsedCode: Sendable {
    var payload: Payload
    var issues: Set<DecodeIssue> = []
    var allowsHandoff: Bool { issues.isEmpty }
}

enum DecodeIssue: String, Sendable {
    case malformed, ambiguous, unsupported, tooLarge
}

enum ParseSupport {
    static let maximumBytes = 32_768

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = trimmed(value)
        return result.isEmpty ? nil : result
    }

    static func decoded(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    static func lines(_ value: String) -> [String] {
        value.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    static func decimal(_ value: String?, exponent: Bool = false) -> Decimal? {
        guard let value = nonempty(value), value.utf8.count <= 64, value.filter(\.isNumber).count <= 38,
              matches(value, exponent ? #"^[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]{1,2})?$"# : #"^[0-9]+(?:\.[0-9]+)?$"#),
              let result = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")),
              !result.isNaN else { return nil }
        return result
    }

    static func dateComponents(_ value: String?) -> DateComponents? {
        guard let value, matches(value, #"^[0-9]{8}$"#) else { return nil }
        let parts = DateComponents(year: Int(value.prefix(4)), month: Int(value.dropFirst(4).prefix(2)), day: Int(value.suffix(2)))
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: parts), calendar.dateComponents([.year, .month, .day], from: date) == parts else { return nil }
        return parts
    }

    static func query(_ value: String) -> (fields: [String: String], duplicate: Bool) {
        guard let marker = value.firstIndex(of: "?") else { return ([:], false) }
        let query = value[value.index(after: marker)...].split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
        var fields: [String: String] = [:]
        var duplicate = false
        for item in query.split(separator: "&", omittingEmptySubsequences: false) {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = pair.first, !key.isEmpty else { continue }
            let name = decoded(String(key))
            let content = pair.count > 1 ? decoded(String(pair[1])) : ""
            if fields[name] != nil { duplicate = true } else { fields[name] = content }
        }
        return (fields, duplicate)
    }

    static func scheme(_ value: String) -> String? {
        guard let colon = value.firstIndex(of: ":") else { return nil }
        let scheme = String(value[..<colon])
        return matches(scheme, #"^[A-Za-z][A-Za-z0-9+.-]*$"#) ? scheme.lowercased() : nil
    }

    static func body(_ value: String) -> String {
        guard let colon = value.firstIndex(of: ":") else { return value }
        return String(value[value.index(after: colon)...])
    }

    static func escapedFields(_ value: String, separator: Character = ";") -> [(String, String)] {
        splitEscaped(value, separator: separator).compactMap { field in
            guard let colon = field.firstIndex(of: ":") else { return nil }
            return (String(field[..<colon]).uppercased(), unescape(String(field[field.index(after: colon)...])))
        }
    }

    static func splitEscaped(_ value: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var escaped = false
        for character in value {
            if character == separator && !escaped {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
            if character == "\\" && !escaped { escaped = true } else { escaped = false }
        }
        parts.append(current)
        return parts
    }

    static func unescape(_ value: String) -> String {
        var result = ""
        var escaped = false
        for character in value {
            if escaped {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        if escaped { result.append("\\") }
        return result
    }

    static func fieldMap(_ entries: [(String, String)]) -> (fields: [String: String], duplicate: Bool) {
        var fields: [String: String] = [:]
        var duplicate = false
        for (key, value) in entries {
            if fields[key] != nil { duplicate = true } else { fields[key] = value }
        }
        return (fields, duplicate)
    }
}
