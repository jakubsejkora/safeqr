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

