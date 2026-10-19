import Foundation
import SafeQRKit

struct CameraObservation: Sendable {
    let code: ScannedCode
    let scene: ScenePhoto?
    let frameSize: CGSize
    let ultraBounds: CodeBounds?
    let ultraSize: CGSize
}

struct TrackedCode: Identifiable {
    let id = UUID()
    var observation: CameraObservation
    var bounds: CodeBounds
    var ultraBounds: CodeBounds?
    let analysis: CodeAnalysis
    var stability: CodeStability

    init(observation: CameraObservation) {
        self.observation = observation
        bounds = observation.code.bounds
        stability = CodeStability(bounds: observation.code.bounds)
        ultraBounds = observation.ultraBounds
        analysis = CodeInspector(locale: L10n.locale).inspect(observation.code.raw, symbology: observation.code.symbology)
    }

    var title: String {
        let detail: String?
        switch analysis.content.payload {
        case .link(let url), .appLink(let url): detail = url.host(percentEncoded: false).map { PublicSuffixRules.bundled.registrableDomain($0) }
        case .payment: detail = analysis.content.facts.first(where: { $0.id == "amount" })?.value
        case .sms(let recipient, _): detail = recipient
        case .wifi(let network): detail = network.ssid
        default: detail = nil
        }
        let kind: String
        switch analysis.content.payload {
        case .link: kind = L10n.text("Link")
        case .payment: kind = L10n.text("Payment")
        case .sms: kind = L10n.text("SMS")
        case .wifi: kind = L10n.text("Wi-Fi")
        default: kind = analysis.content.title
        }
        return [kind, detail].compactMap { $0 }.joined(separator: " · ")
    }
}
