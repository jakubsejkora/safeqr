import Foundation

enum ResourceData {
    static func load<T: Decodable>(_ name: String, extension suffix: String = "json", as type: T.Type = T.self) -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: suffix),
              let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(type, from: data) else {
            preconditionFailure("Missing or invalid bundled resource: \(name)")
        }
        return decoded
    }

    static let banks = load("czech-bank-codes", as: BankDirectory.self).banks
    static let premium = load("premium-numbers", as: PremiumDirectory.self)
    static let brands = load("official-domains", as: BrandDirectory.self).brands
    static let shorteners = Set(load("url-shorteners", as: ShortenerDirectory.self).domains)
    static let currencies = load("iso-currencies", as: CurrencyDirectory.self).codes
}

struct CurrencyDirectory: Decodable, Sendable {
    let codes: [String: String]
}

struct BankDirectory: Decodable, Sendable {
    struct Bank: Decodable, Sendable {
        let code: String
        let name: String
        let bic: String?
    }
    let banks: [Bank]
}

struct BrandDirectory: Decodable, Sendable {
    struct Brand: Decodable, Sendable {
        let name: String
        let domains: [String]
        let aliases: [String]
    }
    let brands: [Brand]
}

struct ShortenerDirectory: Decodable, Sendable {
    let domains: [String]
}

struct PremiumDirectory: Decodable, Sendable {
    struct VoiceRange: Decodable, Sendable {
        let prefix: String
        let unit: String
        let nationalNumberLength: Int
        let priceFormula: String
        let priceFormulaVerified: Bool
    }
    struct SMS: Decodable, Sendable {
        struct Format: Decodable, Sendable {
            let length: Int
            let maxPriceCzk: Int?
            let verified: Bool
        }
        struct Range: Decodable, Sendable {
            let prefix: String
            let status: String
        }
        let formats: [Format]
        let ranges: [Range]
    }
    struct InternationalRange: Decodable, Sendable {
        let prefix: String
    }
    struct InternationalPremiumRange: Decodable, Sendable {
        let pattern: String
    }
    struct Donation: Decodable, Sendable {
        let number: String
        let amountsCzk: [Int]
    }
    let domesticPremiumRanges: [VoiceRange]
    let premiumSms: SMS
    let irsfPrefixes: [InternationalRange]
    let internationalPremiumRanges: [InternationalPremiumRange]
    let donorSms: Donation
}
