import Foundation

enum PayloadParser {
    static func parse(_ raw: String) -> ParsedCode {
        guard raw.utf8.count <= ParseSupport.maximumBytes else { return ParsedCode(payload: .text(""), issues: [.tooLarge]) }
        let value = ParseSupport.trimmed(raw)
        let upper = value.uppercased()
        if let login = LoginParser.parse(value) { return login }
        if upper.hasPrefix("LPA:") { return ESIMParser.parse(value) }
        if let payment = PaymentParser.parse(value) { return payment }
        if let crypto = CryptoParser.parse(value) { return crypto }
        if upper.hasPrefix("WIFI:") { return WiFiParser.parse(value) }
        if upper.hasPrefix("BEGIN:VCARD") || upper.hasPrefix("MECARD:") || upper.hasPrefix("BIZCARD:") { return ContactParser.parse(value) }
        if upper.hasPrefix("BEGIN:VEVENT") || upper.hasPrefix("BEGIN:VCALENDAR") { return CalendarParser.parse(value) }
        switch ParseSupport.scheme(value) {
        case "sms", "smsto", "mms", "mmsto": return SMSParser.parse(value)
        case "tel": return PhoneParser.parse(value)
        case "mailto", "matmsg": return EmailParser.parse(value)
        case "geo": return LocationParser.parse(value)
        default: break
        }
        if let messaging = MessagingParser.parse(value) { return messaging }
        if ParseSupport.matches(value, #"(?i)^https?://.*\s+https?://"#) { return ParsedCode(payload: .text(value)) }
        if let link = LinkParser.parse(value) {
            if case .link(let url) = link.payload, let app = AppLinkParser.parse(url.absoluteString) { return app }
            return link
        }
        if let app = AppLinkParser.parse(value) { return app }
        if let scheme = ParseSupport.scheme(value), ["http", "https", "javascript", "data", "file"].contains(scheme) {
            return ParsedCode(payload: .text(value), issues: [.malformed])
        }
        return ParsedCode(payload: .text(value))
    }
}
