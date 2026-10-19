import Foundation

enum LoginParser {
    static func parse(_ raw: String) -> ParsedCode? {
        let lower = raw.lowercased()
        let scheme = ParseSupport.scheme(raw)
        let components = URLComponents(string: raw)
        let host = components?.host?.lowercased() ?? ""
        let path = components?.path.lowercased() ?? ""
        var login: LoginCode
        var issues: Set<DecodeIssue> = []
        if scheme == "otpauth-migration" { return AuthenticatorExportParser.parse(raw) }
        if scheme == "otpauth" {
            login = LoginCode(service: .authenticatorSetup)
            let query = ParseSupport.query(raw)
            login.issuer = query.fields["issuer"]
            login.account = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !["totp", "hotp"].contains(host) || !ParseSupport.matches(query.fields["secret"] ?? "", #"^[A-Za-z2-7]+=*$"#) { issues.insert(.malformed) }
            if query.duplicate { issues.insert(.ambiguous) }
        } else if scheme == "fido", lower.hasPrefix("fido:/") {
            login = LoginCode(service: .passkey)
        } else if scheme == "tg", host == "login" {
            login = LoginCode(service: .telegram)
            if ParseSupport.query(raw).fields["token"]?.isEmpty != false { issues.insert(.malformed) }
        } else if ["discord.com", "discordapp.com"].contains(host), path.hasPrefix("/ra/") {
            login = LoginCode(service: .discord)
        } else if (host == "s.team" && path.hasPrefix("/q/")) || (scheme == "steam" && host == "login") {
            login = LoginCode(service: .steam)
        } else if (host == "wa.me" && path.hasPrefix("/settings/linked_devices"))
            || (scheme == "whatsapp" && ["link", "linkdevice"].contains(host)) || isWhatsAppWeb(raw) {
            login = LoginCode(service: .whatsAppWeb)
        } else { return nil }
        return ParsedCode(payload: .login(login), issues: issues)
    }

    private static func isWhatsAppWeb(_ raw: String) -> Bool {
        let parts = raw.components(separatedBy: ",")
        guard (4...5).contains(parts.count), parts[0].contains("@"), parts[0].count >= 10 else { return false }
        return parts.dropFirst().prefix(3).allSatisfy {
            $0.count >= 20 && ParseSupport.matches($0, #"^[A-Za-z0-9+/=_-]+$"#)
        }
    }
}
