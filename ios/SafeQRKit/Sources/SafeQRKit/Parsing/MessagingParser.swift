import Foundation

enum MessagingParser {
    static func parse(_ raw: String) -> ParsedCode? {
        let candidate = ParseSupport.scheme(raw) == nil ? "https://" + raw : raw
        guard let url = URL(string: candidate), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = components.host?.lowercased() ?? ""
        let scheme = components.scheme?.lowercased() ?? ""
        guard ["http", "https", "whatsapp", "tg", "sgnl", "viber"].contains(scheme) else { return nil }
        let fields = ParseSupport.query(candidate)
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var link: MessagingLink
        if host == "wa.me" || (host == "api.whatsapp.com" && path == "send") || scheme == "whatsapp" {
            link = MessagingLink(app: .whatsApp, url: url)
            link.recipient = fields.fields["phone"] ?? (host == "wa.me" ? ParseSupport.nonempty(path) : nil)
            link.prefilledText = fields.fields["text"]
        } else if host == "t.me" || host == "telegram.me" || scheme == "tg" {
            link = MessagingLink(app: .telegram, url: url)
            link.recipient = fields.fields["domain"] ?? fields.fields["phone"] ?? (scheme == "tg" ? nil : ParseSupport.nonempty(path))
            link.prefilledText = fields.fields["text"] ?? fields.fields["message"]
        } else if host == "signal.me" || scheme == "sgnl" {
            link = MessagingLink(app: .signal, url: url)
            link.recipient = components.fragment.map { $0.replacingOccurrences(of: "p/", with: "") }
            link.prefilledText = fields.fields["text"]
        } else if scheme == "viber" {
            link = MessagingLink(app: .viber, url: url)
            link.recipient = fields.fields["number"] ?? fields.fields["chatURI"]
            link.prefilledText = fields.fields["text"]
        } else { return nil }
        var issues: Set<DecodeIssue> = fields.duplicate ? [.ambiguous] : []
        if LinkParser.containsControls(raw) { issues.insert(.malformed) }
        if scheme == "tg" && !["resolve", "msg", "msg_url", "join", "privatepost", "share", "addstickers"].contains(host) { issues.insert(.unsupported) }
        if scheme == "whatsapp" && !["send", "chat"].contains(host) { issues.insert(.unsupported) }
        return ParsedCode(payload: .messaging(link), issues: issues)
    }
}
