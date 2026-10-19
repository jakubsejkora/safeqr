import Foundation

enum SMSParser {
    static func parse(_ raw: String) -> ParsedCode {
        let query = ParseSupport.query(raw)
        var body = query.fields["body"]
        let content = ParseSupport.body(raw)
        if ParseSupport.scheme(raw) == "smsto", let colon = content.firstIndex(of: ":") {
            let recipient = ParseSupport.decoded(String(content[..<colon]))
            let body = ParseSupport.decoded(String(content[content.index(after: colon)...]))
            return ParsedCode(payload: .sms(recipient: recipient, body: body),
                              issues: validRecipients(recipient) ? [] : [.malformed])
        }
        var recipient = String(content.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0])
        if let marker = recipient.range(of: ";body=", options: .caseInsensitive) {
            body = ParseSupport.decoded(String(recipient[marker.upperBound...]))
            recipient = String(recipient[..<marker.lowerBound])
        }
        recipient = ParseSupport.decoded(recipient)
        var issues: Set<DecodeIssue> = query.duplicate ? [.ambiguous] : []
        if !validRecipients(recipient) { issues.insert(.malformed) }
        return ParsedCode(payload: .sms(recipient: recipient, body: body), issues: issues)
    }

    private static func validRecipients(_ value: String) -> Bool {
        ParseSupport.matches(value, #"^[+0-9(). ,;-]+$"#) && value.contains(where: \.isNumber)
            && !LinkParser.containsControls(value)
    }
}
