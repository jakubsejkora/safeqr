import Foundation

/// Decodes and assesses scanned codes entirely on device.
public struct CodeInspector: Sendable {
    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    /// Inspects decoded scanner text without opening links or handing data to other apps.
    public func inspect(_ raw: String, symbology: Symbology = .qr) -> CodeAnalysis {
        let parsed = PayloadParser.parse(raw)
        let localizer = Localizer(locale: locale)
        let outcomes = OutcomeBuilder(localizer: localizer)
        let embedded = parsed.issues.contains(.tooLarge) ? EmbeddedPayloads.Result() : EmbeddedPayloads.inspect(parsed.payload, raw: raw)
        let assessment = RiskEngine.assess(parsed, embedded: embedded, raw: raw, localizer: localizer,
                                           consequences: outcomes.consequences(parsed),
                                           limitations: outcomes.limitations(parsed, embedded: embedded))
        let content = parsed.issues.contains(.tooLarge)
            ? CodeContent(kind: .text, payload: parsed.payload, title: localizer.text("title.text"),
                          summary: localizer.text("summary.tooLarge"), facts: [])
            : ContentBuilder(localizer: localizer).build(parsed.payload, raw: raw, embedded: embedded)
        return CodeAnalysis(
            raw: raw,
            symbology: symbology,
            content: content,
            assessment: assessment,
            actions: ActionBuilder(localizer: localizer).build(parsed, raw: raw, assessment: assessment)
        )
    }
}
