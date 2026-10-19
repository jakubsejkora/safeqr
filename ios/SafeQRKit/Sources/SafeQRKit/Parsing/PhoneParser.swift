import Foundation

enum PhoneParser {
    static func parse(_ raw: String) -> ParsedCode {
        let number = ParseSupport.decoded(ParseSupport.body(raw))
        let parts = number.components(separatedBy: ";")
        var main = parts[0]
        var issues: Set<DecodeIssue> = []
        var parameters: [String: String] = [:]
        for parameter in parts.dropFirst() {
            let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { issues.insert(.malformed); continue }
            let key = pair[0].lowercased()
            if parameters[key] != nil { issues.insert(.ambiguous) }
            parameters[key] = String(pair[1])
            if !["ext", "phone-context"].contains(key) { issues.insert(.unsupported) }
        }
        if let context = parameters["phone-context"] {
            if ParseSupport.matches(context, #"^\+[0-9-]+$"#), !main.hasPrefix("+") {
                main = normalized(context) + normalized(main)
            } else { issues.insert(.unsupported) }
        }
        if let suffix = parameters["ext"], !ParseSupport.matches(suffix, #"^[0-9]{1,20}$"#) { issues.insert(.malformed) }
        let valid = ParseSupport.matches(main, #"^[+0-9*#(). -]+$"#) && main.contains(where: \.isNumber) && main.utf8.count <= 64
        if !valid || LinkParser.containsControls(number) { issues.insert(.malformed) }
        if PhoneRules.isIncompletePremiumNumber(main) { issues.insert(.malformed) }
        if !main.contains("*") && !main.contains("#") && main.filter(\.isNumber).count > 15 { issues.insert(.malformed) }
        let destination = main + (parameters["ext"].map { ";ext=" + $0 } ?? "")
        return ParsedCode(payload: .phone(number: issues.contains(.unsupported) ? number : destination), issues: issues)
    }

    static func normalized(_ value: String) -> String {
        let value = value.filter { !" ()-.".contains($0) }
        return value.hasPrefix("00") ? "+" + value.dropFirst(2) : value
    }
}
