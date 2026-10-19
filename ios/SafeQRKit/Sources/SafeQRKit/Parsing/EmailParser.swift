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
            let headers = ParseSupport.fieldMap(query.fields.map { ($0.key.lowercased(), $0.value) })
            subject = headers.fields["subject"]
            body = headers.fields["body"]
            if query.duplicate || headers.duplicate || headers.fields["cc"] != nil || headers.fields["bcc"] != nil || headers.fields["to"] != nil {
                issues.insert(.ambiguous)
            }
        }
        if !ParseSupport.matches(recipient, #"^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$"#)
            || subject.map(LinkParser.containsControls) == true { issues.insert(.malformed) }
        return ParsedCode(payload: .email(recipient: recipient, subject: subject, body: body), issues: issues)
    }
}
