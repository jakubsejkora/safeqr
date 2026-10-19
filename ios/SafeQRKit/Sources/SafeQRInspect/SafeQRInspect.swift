import Foundation
import SafeQRKit

@main
struct SafeQRInspect {
    static func main() {
        var arguments = CommandLine.arguments.dropFirst()
        var language = "en"
        var payloads: [String] = []
        while let argument = arguments.popFirst() {
            switch argument {
            case "--locale":
                guard let value = arguments.popFirst(), ["cs", "en"].contains(value) else {
                    fail("--locale requires cs or en.")
                }
                language = value
            case "--":
                payloads.append(contentsOf: arguments)
                arguments = []
            case "--help", "-h":
                print("Usage: safeqr-inspect [--locale cs|en] [--] [payload ...]\nWithout payload arguments, reads one payload per line from stdin. Default locale: en.")
                return
            default:
                guard !argument.hasPrefix("-") else { fail("Unknown option; use -- before payloads starting with a dash.") }
                payloads.append(argument)
            }
        }
        let inspector = CodeInspector(locale: Locale(identifier: language))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            if payloads.isEmpty {
                while let line = readLine() { try emit(line, inspector: inspector, encoder: encoder) }
            } else {
                for payload in payloads { try emit(payload, inspector: inspector, encoder: encoder) }
            }
        } catch {
            fail("Could not write inspection JSON.", status: 1)
        }
    }

    private static func emit(_ payload: String, inspector: CodeInspector, encoder: JSONEncoder) throws {
        var data = try encoder.encode(Inspection(inspector.inspect(payload)))
        data.append(0x0A)
        try FileHandle.standardOutput.write(contentsOf: data)
    }

    private static func fail(_ message: String, status: Int32 = 64) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(status)
    }
}
