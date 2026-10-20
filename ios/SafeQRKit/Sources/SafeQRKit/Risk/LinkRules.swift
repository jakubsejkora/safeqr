import Foundation

enum LinkRules {
    static func evaluate(_ url: URL, original: String) -> [RiskSignal] {
        var signals: [RiskSignal] = []
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scheme = url.scheme?.lowercased() ?? ""
        let host = (components?.host ?? "").lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let asciiHost = (url.host(percentEncoded: false) ?? "").lowercased()
        if ["javascript", "data", "file"].contains(scheme) { signals.append(RiskSignal("link.unsafeScheme", 95, floor: 95)) }
        if scheme == "http" { signals.append(RiskSignal("link.http", 30)) }
        if components?.user != nil || components?.password != nil { signals.append(RiskSignal("link.userinfo", 70, floor: 70, arguments: [host])) }
        if isIPAddress(host) { signals.append(RiskSignal("link.ipHost", 35)) }
        if let port = components?.port, port != (scheme == "https" ? 443 : 80) { signals.append(RiskSignal("link.port", 15, arguments: [String(port)])) }
        if asciiHost.contains("xn--") || original.lowercased().contains("xn--") { signals.append(RiskSignal("link.punycode", 30)) }
        if mixedScripts(host) { signals.append(RiskSignal("link.mixedScripts", 45, floor: 30)) }
        if let brand = impersonatedBrand(host) { signals.append(RiskSignal("link.impersonation", 75, floor: 70, arguments: [brand.name, brand.domains[0]])) }
        if ResourceData.shorteners.contains(where: { LinkParser.hostMatches(host, domain: $0) }) { signals.append(RiskSignal("link.shortener", 30)) }
        if ["zip", "mov", "click", "top", "gq", "tk"].contains(host.split(separator: ".").last.map(String.init) ?? "") {
            signals.append(RiskSignal("link.unusualTLD", 10))
        }
        if original.utf8.count > 2_048 { signals.append(RiskSignal("link.long", 15)) }
        if original.filter({ $0 == "%" }).count >= 12 || ParseSupport.matches(original, #"(?i)%25(?:2f|3a|40|2e)"#) {
            signals.append(RiskSignal("link.encoded", 20))
        }
        let redirectKeys: Set<String> = ["url", "uri", "redirect", "redirect_url", "redirect_uri", "redirecturl", "return", "returnurl", "return_url", "next", "continue", "target", "dest", "destination", "to"]
        for (key, value) in ParseSupport.query(url.absoluteString).fields where ["http", "https"].contains(scheme) && redirectKeys.contains(key.lowercased()) {
            var target = value
            for _ in 0..<2 { target = ParseSupport.decoded(target) }
            if target.hasPrefix("//") { target = "https:" + target }
            if let destination = URL(string: target), let destinationHost = destination.host()?.lowercased(), destinationHost != asciiHost {
                signals.append(RiskSignal("link.redirect", 30, arguments: [destinationHost]))
                break
            }
        }
        switch url.pathExtension.lowercased() {
        case "mobileconfig": signals.append(RiskSignal("app.profile", 85, floor: 80))
        case "apk", "ipa": signals.append(RiskSignal("app.download", 70, floor: 70))
        default: break
        }
        return signals
    }

    static func isIPAddress(_ host: String) -> Bool {
        host.contains(":") || ParseSupport.matches(host, #"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$"#)
            || ParseSupport.matches(host, #"^(?:0x[0-9a-f]+|[0-9]{7,10})$"#)
    }

    static func mixedScripts(_ value: String) -> Bool {
        value.split(separator: ".").contains { label in
            var scripts = Set<Int>()
            for scalar in label.unicodeScalars where scalar.properties.isAlphabetic {
                switch scalar.value {
                case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F, 0x1E00...0x1EFF: scripts.insert(1)
                case 0x370...0x3FF: scripts.insert(2)
                case 0x400...0x52F: scripts.insert(3)
                case 0x590...0x5FF: scripts.insert(4)
                case 0x600...0x6FF, 0x750...0x77F, 0x8A0...0x8FF: scripts.insert(5)
                case 0x900...0x97F: scripts.insert(6)
                case 0x3040...0x30FF, 0x3400...0x9FFF: scripts.insert(7)
                default: scripts.insert(8)
                }
            }
            return scripts.count > 1
        }
    }

    static func skeleton(_ value: String) -> String {
        let replacements: [Character: Character] = ["а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x", "і": "i", "ј": "j", "ѕ": "s", "ο": "o", "ρ": "p", "ν": "v", "ι": "i", "0": "o", "1": "l"]
        return String(value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .map { replacements[$0] ?? $0 }.filter { $0.isLetter || $0.isNumber })
    }

    static func impersonatedBrand(_ host: String) -> BrandDirectory.Brand? {
        let labels = host.split(separator: ".").map(String.init)
        guard !labels.isEmpty else { return nil }
        // A known host is still checked by every other rule; this only suppresses a false impersonation match.
        if ResourceData.brands.contains(where: { $0.domains.contains { LinkParser.hostMatches(host, domain: $0) } }) { return nil }
        let candidates = labels.map(skeleton)
        let tokens = labels.flatMap { $0.split(separator: "-").map { skeleton(String($0)) } }
        let baitWords: Set<String> = ["login", "secure", "security", "verify", "verification", "platba", "platby", "pay", "payment", "payments", "parking", "online", "auth", "bank", "refund", "support", "delivery", "tracking", "cz"]
        for brand in ResourceData.brands {
            for domain in brand.domains where host.contains(domain + ".") { return brand }
            let names = Set(brand.aliases + brand.domains.compactMap { domain -> String? in
                PublicSuffixRules.bundled.registrableDomain(domain).split(separator: ".").first.map(String.init)
            })
            for name in names {
                let canonical = skeleton(name)
                if candidates.contains(canonical) || tokens.contains(canonical) { return brand }
                if canonical.count >= 4 && candidates.contains(where: { candidate in
                    (candidate.hasPrefix(canonical) && baitWords.contains(String(candidate.dropFirst(canonical.count))))
                        || (candidate.hasSuffix(canonical) && baitWords.contains(String(candidate.dropLast(canonical.count))))
                }) { return brand }
                if canonical.count >= 4 && candidates.contains(where: { oneEditApart($0, canonical) }) { return brand }
            }
        }
        return nil
    }

    private static func oneEditApart(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs), right = Array(rhs)
        guard abs(left.count - right.count) <= 1 else { return false }
        if left.count == right.count {
            let differences = left.indices.filter { left[$0] != right[$0] }
            if differences.count <= 1 { return true }
            if differences.count == 2 {
                let a = differences[0], b = differences[1]
                return b == a + 1 && left[a] == right[b] && left[b] == right[a]
            }
            return false
        }
        let shorter = left.count < right.count ? left : right
        let longer = left.count < right.count ? right : left
        var index = 0
        while index < shorter.count && shorter[index] == longer[index] { index += 1 }
        return Array(shorter[index...]) == Array(longer[(index + 1)...])
    }
}
