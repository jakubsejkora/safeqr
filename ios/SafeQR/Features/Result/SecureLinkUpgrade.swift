import Foundation
import SafeQRKit

enum SecureLinkUpgrade {
    static func destination(for original: URL, hops: [LinkReport.Hop]) -> URL? {
        guard original.scheme?.lowercased() == "http",
              let host = original.host()?.lowercased(), !host.isEmpty,
              HandoffURLBuilder.url(for: .open(original)) != nil,
              let first = hops.first, let firstURL = URL(string: first.url),
              navigationURL(firstURL) == navigationURL(original) else { return nil }
        let domain = PublicSuffixRules.bundled.registrableDomain(host)
        var previous = first
        for hop in hops.dropFirst() {
            guard let url = URL(string: hop.url), let host = url.host()?.lowercased(), !host.isEmpty,
                  PublicSuffixRules.bundled.registrableDomain(host) == domain,
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  HandoffURLBuilder.url(for: .open(url)) != nil else { return nil }
            // A later return from another site is not evidence that the original site chose HTTPS.
            switch hop.via {
            case "http":
                if let status = previous.status, ![301, 302, 303, 307, 308].contains(status) { return nil }
            case "meta", "javascript": break
            default: return nil
            }
            if url.scheme?.lowercased() == "https" { return url }
            previous = hop
        }
        return nil
    }

    private static func navigationURL(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if components.path.isEmpty { components.path = "/" }
        if components.port == 80 { components.port = nil }
        components.fragment = nil
        return components.url
    }
}
