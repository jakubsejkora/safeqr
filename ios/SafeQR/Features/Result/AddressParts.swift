import Foundation

struct AddressParts: Equatable {
    let prefix: String
    let domain: String
    let suffix: String
    let suspiciousLabels: Set<String>
    let unencrypted: Bool

    init(url: URL) {
        let host = url.host(percentEncoded: false) ?? ""
        let domain = PublicSuffixRules.bundled.registrableDomain(host)
        prefix = String(host.dropLast(domain.count))
        self.domain = host.isEmpty ? (url.scheme ?? "") : domain
        // Credentials and token values are never repeated in an address preview.
        suffix = (host.isEmpty ? ":" : "") + (url.port.map { ":\($0)" } ?? "") + url.path(percentEncoded: true)
            + (url.query == nil ? "" : "?…")
        suspiciousLabels = Set(host.split(separator: ".").map(String.init).filter { label in
            label.lowercased().hasPrefix("xn--") || label.unicodeScalars.contains { (0x370...0x52F).contains($0.value) }
        })
        unencrypted = url.scheme?.lowercased() == "http"
    }
}

struct PublicSuffixRules {
    let exact: Set<String>
    let wildcards: Set<String>
    let exceptions: Set<String>

    static let bundled: PublicSuffixRules = {
        let text = Bundle.main.url(forResource: "public_suffix_list", withExtension: "dat")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return PublicSuffixRules(text: text)
    }()

    init(text: String) {
        let rules = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("//") && !$0.isEmpty }
        func ascii(_ rule: String) -> String { URL(string: "https://" + rule)?.host(percentEncoded: false) ?? rule }
        exact = Set(rules.filter { !$0.hasPrefix("*.") && !$0.hasPrefix("!") }.map(ascii))
        wildcards = Set(rules.filter { $0.hasPrefix("*.") }.map { ascii(String($0.dropFirst(2))) })
        exceptions = Set(rules.filter { $0.hasPrefix("!") }.map { ascii(String($0.dropFirst())) })
    }

    func registrableDomain(_ host: String) -> String {
        guard !host.contains(":"), !host.allSatisfy({ $0.isNumber || $0 == "." }), !exact.isEmpty else { return host }
        let labels = host.lowercased().split(separator: ".").map(String.init)
        var suffixCount = 1
        for index in labels.indices {
            let candidate = labels[index...].joined(separator: ".")
            if exceptions.contains(candidate) { suffixCount = labels.count - index - 1; break }
            if exact.contains(candidate) { suffixCount = max(suffixCount, labels.count - index) }
            if index > 0, wildcards.contains(candidate) { suffixCount = max(suffixCount, labels.count - index + 1) }
        }
        return host.split(separator: ".").suffix(suffixCount + 1).joined(separator: ".")
    }
}
