import Foundation

enum PhoneRules {
    struct Charge: Sendable {
        let amount: Int?
        let unit: String
    }

    static func isIncompletePremiumNumber(_ raw: String) -> Bool {
        let number = national(String(raw.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]))
        return ParseSupport.matches(number, #"^[0-9]+$"#) && ResourceData.premium.domesticPremiumRanges.contains {
            number.hasPrefix($0.prefix) && number.count != $0.nationalNumberLength
        }
    }

    static func charge(_ raw: String, sms: Bool) -> Charge? {
        let destination = !sms && !raw.lowercased().contains(";phone-context=")
            ? String(raw.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0]) : raw
        let number = national(destination)
        guard number.allSatisfy(\.isASCII), ParseSupport.matches(number, #"^[0-9]+$"#) else { return nil }
        let data = ResourceData.premium
        if sms {
            guard data.premiumSms.ranges.contains(where: { number.hasPrefix($0.prefix) && $0.status == "used" }),
                  let format = data.premiumSms.formats.first(where: { $0.length == number.count }) else { return nil }
            if number.count == 5 { return Charge(amount: nil, unit: "activation") }
            let amount = Int(number.suffix(number.count - 5))
            let verified = format.verified && (amount ?? 0) > 0 && (amount ?? Int.max) <= (format.maxPriceCzk ?? 0)
            return Charge(amount: verified ? amount : nil, unit: number.count == 7 ? "sms" : "incoming")
        }
        guard let range = data.domesticPremiumRanges.first(where: { number.hasPrefix($0.prefix) && number.count == $0.nationalNumberLength }) else { return nil }
        let price = Int(number.dropFirst(3).prefix(2)).map { $0 * (range.priceFormula == "10 * AB" ? 10 : 1) }
        return Charge(amount: range.priceFormulaVerified && (price ?? 0) > 0 ? price : nil, unit: range.unit)
    }

    static func evaluate(_ recipients: String, body: String? = nil, sms: Bool, localizer: Localizer) -> [RiskSignal] {
        var rules: [RiskSignal] = []
        let numbers = recipients.components(separatedBy: CharacterSet(charactersIn: ",;"))
        for raw in numbers where !raw.lowercased().hasPrefix("ext=") && !raw.lowercased().hasPrefix("phone-context=") {
            let normalized = PhoneParser.normalized(raw)
            if !sms && isIncompletePremiumNumber(raw) {
                rules.append(RiskSignal("phone.incompletePremium", 0, severity: .warning))
            }
            if !sms && (normalized.contains("*") || normalized.contains("#")) {
                let forwarding = ParseSupport.matches(normalized, #"^\*{1,2}(?:21|61|62|67|004)\*"#)
                rules.append(RiskSignal(forwarding ? "phone.forwarding" : "phone.serviceCode", 90, floor: 90))
            }
            if let charge = charge(raw, sms: sms) {
                let amount = charge.amount.map { localizer.amount(Decimal($0), currency: "CZK") }
                rules.append(RiskSignal(sms ? "sms.premium" : "phone.premium", 45, floor: 30,
                                       arguments: amount.map { [$0] } ?? [],
                                       detailKey: "charge.\(amount == nil ? (sms ? "unknown" : "unknownCall") : charge.unit)"))
            }
            if normalized.hasPrefix("+") && !normalized.hasPrefix("+420") && !normalized.hasPrefix("+421") {
                if !sms && ResourceData.premium.internationalPremiumRanges.contains(where: { ParseSupport.matches(normalized, $0.pattern) }) {
                    rules.append(RiskSignal("phone.internationalPremium", 45, floor: 30))
                } else if ResourceData.premium.irsfPrefixes.contains(where: { normalized.hasPrefix($0.prefix) }) {
                    rules.append(RiskSignal("phone.wangiri", 30))
                } else { rules.append(RiskSignal("phone.international", 10)) }
            }
            if !sms && ParseSupport.matches(national(raw), #"^(?:118[0-8]|1[24][0-9]{2,3})$"#) { rules.append(RiskSignal("phone.serviceCharge", 30)) }
        }
        if sms, let body {
            let upper = body.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "cs_CZ")).uppercased()
            let cancellation = ParseSupport.matches(upper, #"^\s*STOP(?:\s|$)"#)
            if !cancellation && (ParseSupport.matches(upper, #"^\s*(?:START|ODBER|REG|REGISTRACE|SUBSCRIBE|ANO)(?:\s|$)"#)
                || ParseSupport.matches(upper, #"\b(?:PREDPLATNE|PREDPLATIT|TYDNE|WEEKLY|SUBSCRIPTION)\b"#)) {
                rules.append(RiskSignal("sms.subscription", 40, floor: rules.contains { $0.id == "sms.premium" } ? 70 : 30))
            }
            if national(recipients) == ResourceData.premium.donorSms.number && upper.hasPrefix("DMS ") {
                rules.append(RiskSignal("sms.donation", 30, floor: 30))
                if upper.hasPrefix("DMS TRV ") { rules.append(RiskSignal("sms.subscription", 40, floor: 70)) }
            }
        }
        if numbers.count > 1 && sms { rules.append(RiskSignal("sms.multipleRecipients", 30)) }
        return rules
    }

    static func national(_ raw: String) -> String {
        let value = PhoneParser.normalized(raw)
        return value.hasPrefix("+420") ? String(value.dropFirst(4)) : value
    }
}
