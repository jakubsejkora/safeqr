import Foundation
import SafeQRKit

struct CheckAccepted: Decodable, Sendable {
    let id: String
    let status: CloudEnum<CloudCheck.Status>
    let pollAfterMs: Int
}

struct CloudCheck: Decodable, Sendable {
    enum Status: String, Decodable, Sendable { case running, completed, failed }
    let id: String
    let status: CloudEnum<Status>
    let steps: [CheckStep]
    let result: CloudVerdict?
    let pollAfterMs: Int?
}

struct CheckStep: Decodable, Sendable, Identifiable {
    enum Status: String, Decodable, Sendable { case pending, running, done, skipped, failed }
    let id: String
    let status: CloudEnum<Status>
    let label: String
}

struct CloudVerdict: Decodable, Sendable {
    let score: Int
    let level: CloudEnum<RiskLevel>
    let headline: String
    let findings: [CloudFinding]
    let consequences: [String]
    let limitations: [String]
    let link: LinkReport?
    let scene: SceneReport?
    let intel: [ScamCase]?
    let models: [String]

    var isValid: Bool {
        (0...100).contains(score) && level.value == RiskLevel(score: score) && findings.allSatisfy { $0.finding != nil }
    }

    var assessment: RemoteAssessment {
        RemoteAssessment(score: score, findings: findings.compactMap(\.finding),
                         consequences: consequences, limitations: limitations)
    }
}

struct CloudFinding: Decodable, Sendable {
    let id: String
    let severity: CloudEnum<Finding.Severity>
    let title: String
    let detail: String
    let source: CloudEnum<Finding.Source>

    var finding: Finding? {
        guard let severity = severity.value, let source = source.value else { return nil }
        return Finding(id: id, severity: severity, title: title, detail: detail, source: source)
    }
}

