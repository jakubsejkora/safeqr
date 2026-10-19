import Foundation
import SafeQRKit

struct Inspection: Encodable {
    struct Fact: Encodable {
        let id: String
        let label: String
        let value: String
    }

    struct Finding: Encodable {
        let id: String
        let severity: String
        let title: String
        let detail: String
    }

    let kind: String
    let title: String
    let summary: String
    let facts: [Fact]
    let score: Int
    let level: String
    let findings: [Finding]
    let consequences: [String]
    let limitations: [String]
    let containsSecrets: Bool

    init(_ analysis: CodeAnalysis) {
        kind = analysis.content.kind.rawValue
        title = analysis.content.title
        summary = analysis.content.summary
        facts = analysis.content.facts.map { Fact(id: $0.id, label: $0.label, value: $0.value) }
        score = analysis.assessment.score
        level = analysis.assessment.level.rawValue
        findings = analysis.assessment.findings.map {
            Finding(id: $0.id, severity: $0.severity.rawValue, title: $0.title, detail: $0.detail)
        }
        consequences = analysis.assessment.consequences
        limitations = analysis.assessment.limitations
        containsSecrets = analysis.containsSecrets
    }
}
