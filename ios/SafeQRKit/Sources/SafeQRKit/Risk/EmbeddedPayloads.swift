import Foundation

enum EmbeddedPayloads {
    struct Result {
        var links: [URL] = []
        var codes: [ParsedCode] = []
        var isTruncated = false
    }

    static func inspect(_ payload: Payload, raw: String) -> Result {
        var result = Result()
        var values = fields(payload, raw: raw)
        values += values.map(ParseSupport.decoded)
        values += values.map(ParseSupport.decoded)
        values = values.uniqued(by: { $0 })
        var seen = Set<String>()
        for value in values {
            let explicit = matches(value, pattern: #"(?i)(?:https?://|www\.)[^\s<>"\\;*]+"#)
            let bare = matches(value, pattern: #"(?i)(?<![\p{L}\p{N}_@/.-])(?:[a-z0-9-]+\.)+[a-z]{2,24}(?::[0-9]+)?(?:/[^\s<>"\\;*]*)?"#)
            for match in explicit + bare {
                let candidate = match.trimmingCharacters(in: CharacterSet(charactersIn: ").,]}"))
                let qualified = ParseSupport.scheme(candidate) == nil ? "https://" + candidate : candidate
                if let url = LinkParser.normalize(qualified), seen.insert(url.absoluteString).inserted {
                    guard result.links.count + result.codes.count < 32 else { result.isTruncated = true; return result }
                    result.links.append(url)
                }
            }
            if value.utf8.count <= 4_096, case .link(let url) = LinkParser.parse(ParseSupport.trimmed(value))?.payload,
               seen.insert(url.absoluteString).inserted { result.links.append(url) }
            var nested = matches(value, pattern: #"(?i)(?:sms:|smsto:|tel:|mailto:|bitcoin:|ethereum:|lightning:|solana:|otpauth(?:-migration)?://|tg://login|javascript:|data:|file:|LPA:)[^\s<>"\\]+"#)
            if payload.kind != .payment {
                nested += matches(value, pattern: #"(?im)(?:SPD\*|SID\*|WIFI:|MECARD:|BIZCARD:)[^\r\n]+"#)
            }
            for match in nested {
                if seen.insert(match).inserted {
                    guard result.links.count + result.codes.count < 32 else { result.isTruncated = true; return result }
                    result.codes.append(PayloadParser.parse(match))
                }
            }
        }
        return result
    }

    private static func fields(_ payload: Payload, raw: String) -> [String] {
        switch payload {
        case .payment(let payment): return Array(payment.fields.values) + [payment.message, payment.paymentURL].compactMap { $0 }
        case .wifi(let network): return [network.ssid]
        case .contact(let card):
            return [card.name, card.organization, card.note].compactMap { $0 } + card.urls
                + CardProperties.parse(card.vCard).filter { $0.name != "TEL" }.map(\.value)
        case .event(let event): return [event.title, event.location, event.description, event.url].compactMap { $0 } + CardProperties.parse(event.iCalendar).map(\.value)
        case .sms(_, let body): return [body].compactMap { $0 }
        case .email(_, let subject, let body): return [subject, body].compactMap { $0 }
        case .messaging(let link): return [link.prefilledText].compactMap { $0 }
        case .crypto(let request):
            return [request.message, request.label, request.function == "transactionRequest" ? request.address : nil].compactMap { $0 }
                + Array(request.parameters.values)
        case .text: return [raw]
        case .appLink(let url):
            return ParseSupport.query(url.absoluteString).fields.filter { !["id", "package", "action"].contains($0.key) }.map(\.value)
                + (url.scheme?.lowercased() == "intent" ? [url.fragment ?? ""] : [])
        case .link(let url): return Array(ParseSupport.query(url.absoluteString).fields.values)
        case .location(_, _, let query): return [query].compactMap { $0 }
        case .phone, .login, .eSIM: return []
        }
    }

    private static func matches(_ value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).prefix(33).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }
}
