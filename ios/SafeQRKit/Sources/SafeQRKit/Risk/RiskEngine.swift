import Foundation

enum RiskEngine {
    static func assess(_ parsed: ParsedCode, embedded: EmbeddedPayloads.Result, raw: String,
                       localizer: Localizer, consequences: [String], limitations: [String]) -> RiskAssessment {
        var signals = rules(parsed, raw: raw, localizer: localizer)
        if embedded.isTruncated { signals.append(RiskSignal("content.tooMany", 40, floor: 30)) }
        if !embedded.links.isEmpty || !embedded.codes.isEmpty {
            signals.append(RiskSignal("content.combination", 20))
            if parsed.payload.kind == .payment && !embedded.links.isEmpty { signals.append(RiskSignal("payment.link", 30, floor: 30)) }
            if parsed.payload.kind == .contact && !embedded.links.isEmpty { signals.append(RiskSignal("contact.link", 15)) }
            for url in embedded.links { signals += LinkRules.evaluate(url, original: url.absoluteString) }
            for code in embedded.codes { signals += rules(code, raw: "", localizer: localizer) }
        }
        if containsDirectionControls(raw) { signals.append(RiskSignal("content.hiddenCharacters", 40, floor: 30)) }
        var unique: [String: RiskSignal] = [:]
        for signal in signals {
            if let previous = unique[signal.id], (previous.floor, previous.points) >= (signal.floor, signal.points) { continue }
            unique[signal.id] = signal
        }
        let ordered = unique.values.sorted { $0.severity == $1.severity ? $0.id < $1.id : $0.severity > $1.severity }
        let floor = ordered.map(\.floor).max() ?? 0
        let score = aggregate(points: ordered.map(\.points), floor: floor)
        return RiskAssessment(score: score, floor: floor, findings: ordered.map { $0.finding(localizer) },
                              consequences: consequences, limitations: limitations)
    }

    /// Score = min(100, max(highest hard floor, sum of points for unique rule IDs)); 30 is caution, 70 is danger.
    static func aggregate(points: [Int], floor: Int) -> Int {
        min(100, max(floor, points.reduce(0, +)))
    }

    private static func rules(_ parsed: ParsedCode, raw: String, localizer: Localizer) -> [RiskSignal] {
        var signals = parsed.issues.sorted { $0.rawValue < $1.rawValue }.map {
            RiskSignal("code.\($0.rawValue)", $0 == .ambiguous ? 70 : $0 == .unsupported ? 0 : 40,
                       floor: $0 == .ambiguous ? 70 : 30, severity: $0 == .ambiguous ? .danger : .warning)
        }
        switch parsed.payload {
        case .link(let url): signals += LinkRules.evaluate(url, original: raw)
        case .payment(let payment): signals += PaymentRules.evaluate(payment)
        case .sms(let recipient, let body): signals += PhoneRules.evaluate(recipient, body: body, sms: true, localizer: localizer)
        case .phone(let number):
            if !parsed.issues.contains(.unsupported) { signals += PhoneRules.evaluate(number, sms: false, localizer: localizer) }
        case .wifi(let network):
            if network.security == .open { signals.append(RiskSignal("wifi.open", 30, floor: 30)) }
            if network.security == .wep { signals.append(RiskSignal("wifi.wep", 40, floor: 30)) }
            let name = LinkRules.skeleton(network.ssid)
            if ResourceData.brands.contains(where: { $0.aliases.contains { $0.count >= 4 && name.contains(LinkRules.skeleton($0)) } })
                || ["freewifi", "publicwifi", "airport", "letiste", "policie"].contains(where: { name.contains($0) }) {
                signals.append(RiskSignal("wifi.impersonation", 30))
            }
        case .contact(let card):
            let name = LinkRules.skeleton([card.name, card.organization].compactMap { $0 }.joined(separator: " "))
            let authority = ["policie", "police", "ministerstvo", "financnisprava", "bank", "sporitelna", "csob", "csas", "cnb"]
            if !card.phoneNumbers.isEmpty && authority.contains(where: { name.contains($0) }) { signals.append(RiskSignal("contact.impersonation", 55, floor: 30)) }
            for number in card.phoneNumbers { signals += PhoneRules.evaluate(number, sms: false, localizer: localizer) }
        case .login(let login):
            signals.append(RiskSignal("login.\(login.service.rawValue)", login.service == .authenticatorExport ? 85 : 70, floor: login.service == .authenticatorExport ? 85 : 70))
        case .eSIM: signals.append(RiskSignal("esim.activation", 70, floor: 70))
        case .appLink(let url):
            signals += LinkRules.evaluate(url, original: raw)
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "itms-services" { signals.append(RiskSignal("app.enterprise", 85, floor: 80)) }
            else if scheme == "intent" { signals.append(RiskSignal("app.intent", 60, floor: 30)) }
            else if !["http", "https", "itms-apps", "itms", "market", "javascript", "data", "file"].contains(scheme) {
                signals.append(RiskSignal("app.customScheme", 35, floor: 30))
            }
        case .crypto(let crypto):
            signals.append(RiskSignal("crypto.irreversible", 35, floor: 30))
            if crypto.checksum == .invalid { signals.append(RiskSignal("crypto.checksum", 80, floor: 80)) }
            if crypto.function != nil && crypto.function != "transfer" { signals.append(RiskSignal("crypto.contract", 45, floor: 70)) }
        case .messaging(let link): signals += LinkRules.evaluate(link.url, original: raw)
        case .event, .email, .location, .text: break
        }
        return signals
    }

    private static func containsDirectionControls(_ raw: String) -> Bool {
        raw.unicodeScalars.contains { (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value) }
    }
}
