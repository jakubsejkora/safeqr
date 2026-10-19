import Foundation

enum CardProperties {
    struct Property {
        let name: String
        let parameters: String
        let value: String
    }

    static func parse(_ raw: String) -> [Property] {
        var unfolded: [String] = []
        for line in ParseSupport.lines(raw) {
            if let previous = unfolded.last, previous.uppercased().contains("ENCODING=QUOTED-PRINTABLE"), previous.hasSuffix("=") {
                unfolded[unfolded.count - 1] = String(previous.dropLast()) + line
            } else if line.first == " " || line.first == "\t", !unfolded.isEmpty {
                unfolded[unfolded.count - 1] += line.dropFirst()
            } else { unfolded.append(line) }
        }
        return unfolded.compactMap { line in
            var quoted = false
            let colon = line.indices.first { index in
                if line[index] == "\"" { quoted.toggle() }
                return line[index] == ":" && !quoted
            }
            guard let colon else { return nil }
            let header = String(line[..<colon])
            guard let field = header.split(separator: ";", maxSplits: 1).first else { return nil }
            let name = String(field.split(separator: ".").last ?? "").uppercased()
            let parameters = header.uppercased()
            var value = String(line[line.index(after: colon)...])
            if parameters.contains("ENCODING=QUOTED-PRINTABLE") {
                value = quotedPrintable(value, latin1: parameters.contains("ISO-8859-1"))
            }
            return Property(name: name, parameters: parameters, value: value)
        }
    }

    static func quotedPrintable(_ raw: String, latin1: Bool) -> String {
        let bytes = Array(raw.utf8)
        var output: [UInt8] = []
        var index = 0
        while index < bytes.count {
            if bytes[index] == 61, index + 2 < bytes.count,
               let byte = UInt8(String(decoding: bytes[index + 1...index + 2], as: UTF8.self), radix: 16) {
                output.append(byte)
                index += 3
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return String(data: Data(output), encoding: latin1 ? .isoLatin1 : .utf8) ?? raw
    }
}
