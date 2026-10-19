import Foundation
import Observation
import SafeQRKit

@MainActor @Observable
final class ScanChecks {
    private(set) var models: [String: ResultModel] = [:]

    func result(for analysis: CodeAnalysis, scene: ScenePhoto?, limitations: [String] = [],
                using client: any CloudChecking, consent: CheckConsent) -> ResultModel {
        if let existing = models[analysis.raw] {
            existing.prepare(scene: scene, limitations: limitations)
            existing.start(using: client, consent: consent)
            return existing
        }
        let model = ResultModel(analysis: analysis, scene: scene, extraLimitations: limitations)
        models[analysis.raw] = model
        model.start(using: client, consent: consent)
        return model
    }

    func observe(_ codes: [TrackedCode], sceneContainsPrivateCodes: Bool, using client: any CloudChecking,
                 consent: CheckConsent, now: Date = Date()) {
        guard consent.links else { return }
        for code in codes where code.analysis.hasWebDestination && !code.analysis.containsSecrets {
            guard code.stability.isSteady(at: now), models[code.analysis.raw]?.attemptedCloud != true else { continue }
            let scene = sceneContainsPrivateCodes ? nil : code.observation.scene
            guard consent.request(for: code.analysis, scene: scene) != nil else { continue }
            let limitations = sceneContainsPrivateCodes
                ? [L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")] : []
            _ = result(for: code.analysis, scene: scene, limitations: limitations, using: client, consent: consent)
        }
    }

    func revokeConsent() {
        for model in models.values { model.cancel() }
    }
}
