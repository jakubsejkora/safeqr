import Foundation
import SafeQRKit

struct ScenePhoto: Sendable {
    let jpeg: Data
    let source: Source
    let bounds: CodeBounds?

    enum Source: String, Codable, Sendable {
        case ultraWideCamera, camera, photo
    }
}

struct CodeBounds: Codable, Sendable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(rect: CGRect) {
        let clipped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        x = clipped.isNull ? 0 : clipped.minX
        y = clipped.isNull ? 0 : clipped.minY
        width = clipped.isNull ? 0 : clipped.width
        height = clipped.isNull ? 0 : clipped.height
    }
}

struct CheckRequest: Encodable, Sendable {
    struct Device: Encodable, Sendable {
        let score: Int
        let floor: Int
        let findingIds: [String]
    }

    struct Scene: Encodable, Sendable {
        let image: String
        let source: ScenePhoto.Source
        let codeBounds: CodeBounds?
    }

    let payload: String
    let kind: CodeKind
    let locale: String
    let device: Device
    let scene: Scene?

    init(analysis: CodeAnalysis, scene: ScenePhoto?, locale: Locale = L10n.locale) {
        payload = analysis.raw
        kind = analysis.content.kind
        self.locale = locale.language.languageCode?.identifier == "cs" ? "cs" : "en"
        device = Device(score: analysis.assessment.score, floor: analysis.assessment.floor,
                        findingIds: analysis.assessment.findings.map(\.id))
        self.scene = scene.map { Scene(image: $0.jpeg.base64EncodedString(), source: $0.source, codeBounds: $0.bounds) }
    }
}

struct CheckAccepted: Decodable, Sendable {
    let id: String
    let status: String
    let pollAfterMs: Int
}

struct CloudCheck: Decodable, Sendable {
    enum Status: String, Decodable, Sendable { case running, completed, failed }
    let id: String
    let status: Status
    let steps: [CheckStep]
    let result: CloudVerdict?
    let pollAfterMs: Int?
}

struct CheckStep: Decodable, Sendable, Identifiable {
    enum Status: String, Decodable, Sendable { case pending, running, done, skipped, failed }
    let id: String
    let status: Status
    let label: String
}

struct CloudVerdict: Decodable, Sendable {
    let score: Int
    let level: RiskLevel
    let headline: String
    let findings: [CloudFinding]
    let consequences: [String]
    let limitations: [String]
    let link: LinkReport?
    let scene: SceneReport?
    let intel: [ScamCase]?
    let models: [String]

    var assessment: RemoteAssessment {
        RemoteAssessment(score: score, findings: findings.map(\.finding),
                         consequences: consequences, limitations: limitations)
    }
}

struct CloudFinding: Decodable, Sendable {
    let id: String
    let severity: Finding.Severity
    let title: String
    let detail: String
    let source: Finding.Source

    var finding: Finding {
        Finding(id: id, severity: severity, title: title, detail: detail, source: source)
    }
}

struct LinkReport: Decodable, Sendable {
    struct Hop: Decodable, Sendable {
        let url: String
        let status: Int?
        let via: String
    }
    let finalUrl: String
    let hops: [Hop]
    let pageTitle: String?
    let screenshotUrl: URL?
    let domainAgeDays: Int?
    let asksFor: [String]?
}

struct SceneReport: Decodable, Sendable {
    let setting: String?
    let tamperingSigns: [String]?
    let matchesContent: Bool?
    let summary: String
}

struct ScamCase: Decodable, Sendable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let sourceUrl: URL
    let publishedAt: String
}
