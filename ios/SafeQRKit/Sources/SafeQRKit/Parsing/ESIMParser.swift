import Foundation

enum ESIMParser {
    static func parse(_ raw: String) -> ParsedCode {
        let parts = ParseSupport.body(raw).components(separatedBy: "$")
        let activation = ESIMActivation(smdpAddress: parts.count > 1 ? parts[1] : "",
                                        matchingID: parts.count > 2 ? ParseSupport.nonempty(parts[2]) : nil,
                                        requiresConfirmationCode: parts.count > 4 && parts[4] == "1")
        var issues: Set<DecodeIssue> = []
        if parts[0] != "1" { issues.insert(.unsupported) }
        if parts.count < 3 || activation.smdpAddress.isEmpty || activation.matchingID == nil
            || !ParseSupport.matches(activation.smdpAddress, #"^[A-Za-z0-9.-]+$"#) { issues.insert(.malformed) }
        return ParsedCode(payload: .eSIM(activation), issues: issues)
    }
}
