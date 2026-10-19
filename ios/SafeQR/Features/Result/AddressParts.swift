import Foundation
import SafeQRKit

struct AddressParts: Equatable {
    let prefix: String
    let domain: String
    let suffix: String
    let suspiciousLabels: Set<String>
    let unencrypted: Bool

    init(url: URL) {
        let host = (url.host(percentEncoded: false) ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
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

