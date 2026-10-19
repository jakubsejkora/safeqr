import Foundation

enum EmailParser {
    static func parse(_ raw: String) -> ParsedCode {
        var recipient: String
        var subject: String?
        var body: String?
        var issues: Set<DecodeIssue> = []
        if raw.uppercased().hasPrefix("MATMSG:") {
            let map = ParseSupport.fieldMap(ParseSupport.escapedFields(ParseSupport.body(raw)))
            recipient = map.fields["TO"] ?? ""
            subject = map.fields["SUB"]
            body = map.fields["BODY"]
            if map.duplicate { issues.insert(.ambiguous) }
        } else {
            let query = ParseSupport.query(raw)
            recipient = ParseSupport.decoded(String(ParseSupport.body(raw).split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]))
            subject = query.fields["subject"]
            body = query.fields["body"]
            if query.duplicate || query.fields["cc"] != nil || query.fields["bcc"] != nil || query.fields["to"] != nil {
                issues.insert(.ambiguous)
            }
        }
        if !ParseSupport.matches(recipient, #"^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$"#)
            || subject.map(LinkParser.containsControls) == true { issues.insert(.malformed) }
        return ParsedCode(payload: .email(recipient: recipient, subject: subject, body: body), issues: issues)
    }
}
