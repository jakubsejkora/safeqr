import Foundation

enum AppLinkParser {
    static func store(_ url: URL) -> String? {
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        let scheme = url.scheme?.lowercased() ?? ""
        if ["apps.apple.com", "itunes.apple.com"].contains(host) || ["itms-apps", "itms"].contains(scheme) { return "appStore" }
        if host == "play.google.com" || scheme == "market" { return "googlePlay" }
        return nil
    }

    static func parse(_ raw: String) -> ParsedCode? {
        guard let scheme = ParseSupport.scheme(raw), let url = URL(string: raw) else { return nil }
        if ["http", "https"].contains(scheme) {
            let host = url.host()?.lowercased() ?? ""
            if !["apps.apple.com", "itunes.apple.com", "play.google.com"].contains(host)
                && !["mobileconfig", "apk", "ipa"].contains(url.pathExtension.lowercased()) { return nil }
        }
        return ParsedCode(payload: .appLink(url), issues: LinkParser.containsControls(raw) ? [.malformed] : [])
    }
}
