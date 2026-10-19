import CryptoKit
import Foundation

enum CryptoEncoding {
    static func base58(_ raw: String) -> [UInt8]? {
        guard !raw.isEmpty, raw.utf8.count <= 128 else { return nil }
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
        var result: [UInt8] = []
        for byte in raw.utf8 {
            guard let digit = alphabet.firstIndex(of: byte) else { return nil }
            var carry = digit
            for index in result.indices.reversed() {
                carry += Int(result[index]) * 58
                result[index] = UInt8(carry & 255)
                carry >>= 8
            }
            while carry > 0 { result.insert(UInt8(carry & 255), at: 0); carry >>= 8 }
        }
        return Array(repeating: 0, count: raw.prefix(while: { $0 == "1" }).count) + result
    }

    static func base58Check(_ raw: String, versions: Set<UInt8>) -> Bool {
        guard let data = base58(raw), data.count == 25, versions.contains(data[0]) else { return false }
        let hash = SHA256.hash(data: Data(SHA256.hash(data: Data(data.dropLast(4)))))
        return Array(hash.prefix(4)) == Array(data.suffix(4))
    }

    static func bech32(_ raw: String) -> (hrp: String, words: [UInt8], variant: UInt32)? {
        guard raw.utf8.allSatisfy({ $0 < 128 }), raw == raw.lowercased() || raw == raw.uppercased(),
              let separator = raw.lastIndex(of: "1") else { return nil }
        let lower = raw.lowercased()
        let hrp = String(lower[..<separator])
        guard !hrp.isEmpty, hrp.utf8.allSatisfy({ (33...126).contains($0) }) else { return nil }
        let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l".utf8)
        var words: [UInt8] = []
        for byte in lower[lower.index(after: separator)...].utf8 {
            guard let index = alphabet.firstIndex(of: byte) else { return nil }
            words.append(UInt8(index))
        }
        guard words.count >= 6 else { return nil }
        let expanded = hrp.utf8.map { $0 >> 5 } + [0] + hrp.utf8.map { $0 & 31 } + words
        let generators: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var check: UInt32 = 1
        for value in expanded {
            let top = check >> 25
            check = ((check & 0x1ffffff) << 5) ^ UInt32(value)
            for index in 0..<5 where (top >> index) & 1 != 0 { check ^= generators[index] }
        }
        guard check == 1 || check == 0x2bc830a3 else { return nil }
        return (hrp, Array(words.dropLast(6)), check)
    }

    static func bytes(from words: [UInt8], padded: Bool = false) -> [UInt8]? {
        var buffer: UInt32 = 0
        var bits = 0
        var bytes: [UInt8] = []
        for word in words {
            buffer = (buffer << 5) | UInt32(word)
            bits += 5
            if bits >= 8 { bits -= 8; bytes.append(UInt8((buffer >> bits) & 255)) }
        }
        if padded && bits > 0 { bytes.append(UInt8((buffer << (8 - bits)) & 255)) }
        if !padded && (bits >= 5 || ((buffer << (8 - bits)) & 255) != 0) { return nil }
        return bytes
    }

    static func witnessAddress(_ value: String, prefixes: Set<String>) -> Bool {
        guard value.count <= 90, let decoded = bech32(value), prefixes.contains(decoded.hrp),
              let version = decoded.words.first, version <= 16,
              let program = bytes(from: Array(decoded.words.dropFirst())), (2...40).contains(program.count) else { return false }
        if version == 0 { return decoded.variant == 1 && [20, 32].contains(program.count) }
        return decoded.variant == 0x2bc830a3
    }
}
