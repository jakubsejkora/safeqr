import Foundation

enum LinkParser {
    static func parse(_ raw: String) -> ParsedCode? {
        let scheme = ParseSupport.scheme(raw)
        if scheme == "http" || scheme == "https" {
            guard let url = normalize(raw), url.host() != nil else {
                return ParsedCode(payload: .text(raw), issues: [.malformed])
            }
            return ParsedCode(payload: .link(url), issues: containsControls(raw) ? [.malformed] : [])
        }
        if !raw.contains(where: \.isWhitespace)
            && ParseSupport.matches(raw, #"^(?:[\p{L}\p{N}-]+\.)+[\p{L}]{2,63}(?::[0-9]{1,5})?(?:[/\?#].*)?$"#),
           let url = normalize("https://" + raw) {
            return ParsedCode(payload: .link(url))
        }
        return nil
    }

    static func normalize(_ raw: String) -> URL? {
        guard !raw.contains("\\"), var components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              !host.contains(where: \.isWhitespace),
              components.port.map({ (1...65_535).contains($0) }) ?? true else { return nil }
        guard validPort(raw), !host.hasPrefix(".") else { return nil }
        components.scheme = scheme
        components.host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if (scheme == "https" && components.port == 443) || (scheme == "http" && components.port == 80) { components.port = nil }
        if let encoded = components.url?.host(percentEncoded: false), !encoded.contains(":") {
            guard encoded.utf8.count <= 253, encoded.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0.utf8.count <= 63 }) else { return nil }
        }
        return components.url
    }

    private static func validPort(_ raw: String) -> Bool {
        guard let start = raw.range(of: "://") else { return false }
        let authority = raw[start.upperBound...].prefix { !"/?#".contains($0) }
        let hostPort = String(authority.split(separator: "@", omittingEmptySubsequences: false).last ?? "")
        let suffix: String
        if hostPort.hasPrefix("[") {
            guard let end = hostPort.firstIndex(of: "]") else { return false }
            suffix = String(hostPort[hostPort.index(after: end)...])
        } else if let colon = hostPort.lastIndex(of: ":") { suffix = String(hostPort[colon...]) }
        else { return true }
        if suffix.isEmpty { return true }
        guard suffix.hasPrefix(":"), let port = Int(suffix.dropFirst()) else { return false }
        return (1...65_535).contains(port)
    }

    static func containsControls(_ raw: String) -> Bool {
        raw.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }

    static func hostMatches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }
}
