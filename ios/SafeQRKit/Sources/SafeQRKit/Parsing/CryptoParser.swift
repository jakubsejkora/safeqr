import Foundation

enum CryptoParser {
    static func parse(_ raw: String) -> ParsedCode? {
        let scheme = ParseSupport.scheme(raw)
        let lower = raw.lowercased()
        if scheme == "lightning" || lower.hasPrefix("lnbc") || lower.hasPrefix("lntb") { return lightning(raw) }
        var network: CryptoRequest.Network
        switch scheme {
        case "bitcoin": network = .bitcoin
        case "ethereum": network = .ethereum
        case "solana": network = .solana
        case "litecoin": network = .litecoin
        case "tron": network = .tron
        case nil:
            if lower.hasPrefix("bc1") || ParseSupport.matches(raw, #"^[13][1-9A-HJ-NP-Za-km-z]{25,34}$"#) { network = .bitcoin }
            else if ParseSupport.matches(raw, #"^0[xX][0-9a-fA-F]{40}$"#) { network = .ethereum }
            else if ParseSupport.matches(raw, #"^T[1-9A-HJ-NP-Za-km-z]{33}$"#) { network = .tron }
            else { return nil }
        default: return nil
        }
        let query = ParseSupport.query(raw)
        let body = scheme == nil ? raw : ParseSupport.body(raw)
        let target = ParseSupport.decoded(String(body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]))
            .replacingOccurrences(of: "^//", with: "", options: .regularExpression)
        var request = CryptoRequest(network: network, address: target)
        request.parameters = query.fields
        request.label = query.fields["label"]
        request.message = query.fields["message"] ?? query.fields["memo"]
        var issues: Set<DecodeIssue> = query.duplicate ? [.ambiguous] : []
        if query.fields.keys.contains(where: { $0.hasPrefix("req-") }) { issues.insert(.unsupported) }
        if network == .ethereum {
            ethereum(&request, target: target, query: query.fields, issues: &issues)
        } else {
            request.amount = ParseSupport.decimal(query.fields["amount"])
            request.amountUnit = network == .bitcoin ? "BTC" : network == .litecoin ? "LTC" : network == .solana ? "SOL" : "TRX"
            if query.fields["amount"] != nil && request.amount == nil { issues.insert(.malformed) }
            if let contract = query.fields["spl-token"] ?? query.fields["token"] {
                request.assetContract = contract
                request.amountUnit = "token"
            }
            switch network {
            case .bitcoin:
                let valid = target.lowercased().hasPrefix("bc1") || target.lowercased().hasPrefix("tb1")
                    ? CryptoEncoding.witnessAddress(target, prefixes: ["bc", "tb", "bcrt"])
                    : CryptoEncoding.base58Check(target, versions: [0, 5, 111, 196])
                request.checksum = valid ? .valid : .invalid
            case .litecoin:
                let valid = target.lowercased().hasPrefix("ltc1")
                    ? CryptoEncoding.witnessAddress(target, prefixes: ["ltc"])
                    : CryptoEncoding.base58Check(target, versions: [48, 50, 5])
                request.checksum = valid ? .valid : .invalid
            case .tron: request.checksum = CryptoEncoding.base58Check(target, versions: [65]) ? .valid : .invalid
            case .solana:
                if target.lowercased().hasPrefix("https://") {
                    request.function = "transactionRequest"
                } else if CryptoEncoding.base58(target)?.count != 32 { issues.insert(.malformed) }
            default: break
            }
        }
        if request.address.isEmpty { issues.insert(.malformed) }
        return ParsedCode(payload: .crypto(request), issues: issues)
    }

    private static func ethereum(_ request: inout CryptoRequest, target: String, query: [String: String], issues: inout Set<DecodeIssue>) {
        let path = target.hasPrefix("pay-") ? String(target.dropFirst(4)) : target
        let parts = path.components(separatedBy: "/")
        let chain = parts[0].components(separatedBy: "@")
        request.address = chain[0]
        request.chainID = chain.count > 1 ? chain[1] : nil
        request.function = parts.count > 1 ? parts[1] : nil
        if request.function == "transfer" {
            request.assetContract = chain[0]
            request.address = query["address"] ?? ""
            request.amount = ParseSupport.decimal(query["uint256"], exponent: true)
            request.amountUnit = "baseUnits"
            if query["uint256"] == nil || request.amount.map({ !isInteger($0) }) != false { issues.insert(.malformed) }
        } else if let value = query["value"] {
            if let wei = ParseSupport.decimal(value, exponent: true), isInteger(wei) {
                request.amount = wei / Decimal(1_000_000_000_000_000_000 as Int64)
                request.amountUnit = "ETH"
            } else { issues.insert(.malformed) }
        }
        if !ParseSupport.matches(request.address, #"^0[xX][0-9a-fA-F]{40}$"#)
            && !ParseSupport.matches(request.address, #"^[A-Za-z0-9.-]+\.eth$"#) { issues.insert(.malformed) }
        if chain.count > 2 || parts.count > 2 { issues.insert(.malformed) }
    }

    private static func isInteger(_ value: Decimal) -> Bool {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .down)
        return rounded == value
    }

    private static func lightning(_ raw: String) -> ParsedCode {
        let invoice = ParseSupport.scheme(raw) == "lightning" ? ParseSupport.body(raw) : raw
        var request = CryptoRequest(network: .lightning, address: invoice)
        request.amountUnit = "BTC"
        guard let decoded = CryptoEncoding.bech32(invoice), decoded.variant == 1,
              decoded.words.count >= 111,
              ParseSupport.matches(decoded.hrp, #"^ln(?:bc|tb|bcrt)(?:[0-9]+[munp]?)?$"#) else {
            request.checksum = .invalid
            return ParsedCode(payload: .crypto(request), issues: [.malformed])
        }
        request.checksum = .valid
        let prefixLength = decoded.hrp.hasPrefix("lnbcrt") ? 6 : 4
        let amount = String(decoded.hrp.dropFirst(prefixLength))
        if !amount.isEmpty {
            let multipliers: [Character: String] = ["m": "0.001", "u": "0.000001", "n": "0.000000001", "p": "0.000000000001"]
            if let suffix = amount.last, let multiplier = multipliers[suffix] {
                request.amount = ParseSupport.decimal(String(amount.dropLast())).map { $0 * (Decimal(string: multiplier) ?? 0) }
            } else { request.amount = ParseSupport.decimal(amount) }
        }
        let words = Array(decoded.words.dropLast(104))
        var cursor = 7
        var hasPaymentHash = false
        while cursor + 3 <= words.count {
            let tag = words[cursor]
            let length = Int(words[cursor + 1]) * 32 + Int(words[cursor + 2])
            cursor += 3
            guard length <= words.count - cursor else { return ParsedCode(payload: .crypto(request), issues: [.malformed]) }
            let content = Array(words[cursor..<cursor + length])
            if tag == 1 && length == 52 { hasPaymentHash = true }
            if tag == 13, let bytes = CryptoEncoding.bytes(from: content) { request.message = String(bytes: bytes, encoding: .utf8) }
            cursor += length
        }
        let invalid = !hasPaymentHash || cursor != words.count || (amount.hasSuffix("p") && !amount.dropLast().hasSuffix("0"))
        return ParsedCode(payload: .crypto(request), issues: invalid ? [.malformed] : [])
    }
}
