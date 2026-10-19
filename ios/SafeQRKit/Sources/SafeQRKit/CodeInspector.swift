import Foundation

/// Decodes and assesses scanned codes entirely on device.
public struct CodeInspector: Sendable {
    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    public func inspect(_ raw: String, symbology: Symbology = .qr) -> CodeAnalysis {
        CodeAnalysis(
            raw: raw,
            symbology: symbology,
            content: CodeContent(kind: .text, payload: .text(raw), title: "Text", summary: raw, facts: []),
            assessment: RiskAssessment(score: 0, findings: [], consequences: [], limitations: []),
            actions: [CodeAction(id: "copy", kind: .copy(raw), title: "Copy", confirmation: nil)]
        )
    }
}
