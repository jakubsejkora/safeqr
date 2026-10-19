import Foundation

// Future server values remain readable without silently becoming a known safety classification.
enum CloudEnum<Value: RawRepresentable & Sendable>: Decodable, Sendable where Value.RawValue == String {
    case known(Value)
    case unknown(String)

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let value = Value(rawValue: raw) { self = .known(value) }
        else { self = .unknown(raw) }
    }

    var value: Value? {
        if case .known(let value) = self { value } else { nil }
    }
}
