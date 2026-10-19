import Foundation

enum ContactParser {
    static func parse(_ raw: String) -> ParsedCode {
        if !raw.uppercased().hasPrefix("BEGIN:VCARD") { return compactCard(raw) }
        let properties = CardProperties.parse(raw)
        var card = ContactCard(vCard: raw)
        for property in properties {
            let value = ParseSupport.unescape(property.value)
            switch property.name {
            case "FN": card.name = card.name ?? value
            case "N" where card.name == nil:
                let names = ParseSupport.splitEscaped(property.value, separator: ";").map(ParseSupport.unescape)
                card.name = names.count > 1 ? [names[1], names[0]].filter { !$0.isEmpty }.joined(separator: " ") : value
            case "ORG": card.organization = value.replacingOccurrences(of: ";", with: " · ")
            case "TEL": card.phoneNumbers.append(value.lowercased().hasPrefix("tel:") ? ParseSupport.decoded(String(value.dropFirst(4))) : value)
            case "EMAIL": card.emails.append(value)
            case "URL": card.urls.append(value)
            case "NOTE": card.note = [card.note, value].compactMap { $0 }.joined(separator: "\n")
            default: break
            }
        }
        if let formatted = properties.first(where: { $0.name == "FN" }) { card.name = ParseSupport.unescape(formatted.value) }
        var issues: Set<DecodeIssue> = []
        if properties.filter({ $0.name == "BEGIN" && $0.value.uppercased() == "VCARD" }).count != 1 { issues.insert(.ambiguous) }
        if !properties.contains(where: { $0.name == "END" && $0.value.uppercased() == "VCARD" }) { issues.insert(.malformed) }
        if let version = properties.first(where: { $0.name == "VERSION" })?.value, !["2.1", "3.0", "4.0"].contains(version) {
            issues.insert(.unsupported)
        }
        return ParsedCode(payload: .contact(card), issues: issues)
    }

    private static func compactCard(_ raw: String) -> ParsedCode {
        let entries = ParseSupport.escapedFields(ParseSupport.body(raw))
        func first(_ key: String) -> String? { entries.first { $0.0 == key }?.1 }
        var card = ContactCard(vCard: "")
        if raw.uppercased().hasPrefix("MECARD:") {
            if let name = first("N") {
                let parts = name.components(separatedBy: ",")
                card.name = parts.count == 2 ? "\(parts[1]) \(parts[0])" : name
            }
            card.phoneNumbers = entries.filter { $0.0 == "TEL" }.map(\.1)
            card.emails = entries.filter { $0.0 == "EMAIL" }.map(\.1)
            card.urls = entries.filter { $0.0 == "URL" }.map(\.1)
            card.note = first("NOTE")
            card.organization = first("ORG")
        } else {
            card.name = [first("N"), first("X")].compactMap { $0 }.joined(separator: " ")
            card.organization = first("C")
            card.phoneNumbers = entries.filter { ["B", "M", "F"].contains($0.0) }.map(\.1)
            card.emails = entries.filter { $0.0 == "E" }.map(\.1)
            card.note = first("T")
        }
        var lines = ["BEGIN:VCARD", "VERSION:3.0", "FN:\(escape(card.name ?? card.organization ?? ""))"]
        if let organization = card.organization { lines.append("ORG:" + escape(organization)) }
        for phone in card.phoneNumbers { lines.append("TEL:" + escape(phone)) }
        for email in card.emails { lines.append("EMAIL:" + escape(email)) }
        for url in card.urls { lines.append("URL:" + escape(url)) }
        if let note = card.note { lines.append("NOTE:" + escape(note)) }
        lines.append("END:VCARD")
        card.vCard = lines.joined(separator: "\r\n")
        return ParsedCode(payload: .contact(card), issues: entries.isEmpty ? [.malformed] : [])
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }
}
