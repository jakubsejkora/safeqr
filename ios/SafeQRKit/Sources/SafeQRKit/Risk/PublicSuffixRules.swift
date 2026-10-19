import Foundation

/// Public Suffix List boundaries shared by inspection and address presentation.
public struct PublicSuffixRules: Sendable {
    let exact: Set<String>
    let wildcards: Set<String>
    let exceptions: Set<String>

    /// The bundled Mozilla Public Suffix List, including private hosting domains.
    public static let bundled: PublicSuffixRules = {
        let text = Bundle.module.url(forResource: "public_suffix_list", withExtension: "dat")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        return PublicSuffixRules(text: text)
    }()

    /// Creates rules from the standard Public Suffix List format.
    public init(text: String) {
        let rules = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("//") && !$0.isEmpty }
        func ascii(_ rule: String) -> String { URL(string: "https://" + rule)?.host(percentEncoded: false) ?? rule }
        exact = Set(rules.filter { !$0.hasPrefix("*.") && !$0.hasPrefix("!") }.map(ascii))
        wildcards = Set(rules.filter { $0.hasPrefix("*.") }.map { ascii(String($0.dropFirst(2))) })
        exceptions = Set(rules.filter { $0.hasPrefix("!") }.map { ascii(String($0.dropFirst())) })
    }

    /// Returns the domain a registrant controls, retaining IP addresses unchanged.
    public func registrableDomain(_ host: String) -> String {
        guard !host.contains(":"), !host.allSatisfy({ $0.isNumber || $0 == "." }), !exact.isEmpty else { return host }
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let ascii = URL(string: "https://" + normalized)?.host(percentEncoded: false) ?? normalized
        let labels = ascii.lowercased().split(separator: ".").map(String.init)
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
