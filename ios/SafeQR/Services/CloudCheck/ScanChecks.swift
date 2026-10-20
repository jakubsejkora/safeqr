import Foundation
import Observation
import SafeQRKit

@MainActor @Observable
final class ScanChecks {
    static let lifetime: TimeInterval = 600
    static let capacity = 20
    private(set) var models: [String: ResultModel] = [:]
    private var createdAt: [String: Date] = [:]
    @ObservationIgnored private var cleanupTask: Task<Void, Never>?

    init() {
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
                self?.removeExpired()
            }
        }
    }

    deinit { cleanupTask?.cancel() }

    func result(for analysis: CodeAnalysis, scene: ScenePhoto?, limitations: [String] = [],
                using client: any CloudChecking, consent: CheckConsent, now: Date = Date()) -> ResultModel {
        removeExpired(at: now)
        if let existing = models[analysis.raw] {
            existing.prepare(scene: scene, limitations: limitations)
            existing.start(using: client, consent: consent)
            return existing
        }
        if models.count >= Self.capacity, let oldest = createdAt.min(by: { $0.value < $1.value })?.key {
            remove(oldest)
        }
        let model = ResultModel(analysis: analysis, scene: scene, extraLimitations: limitations)
        models[analysis.raw] = model
        createdAt[analysis.raw] = now
        model.start(using: client, consent: consent)
        return model
    }

    func observe(_ codes: [TrackedCode], sceneContainsPrivateCodes: Bool, using client: any CloudChecking,
                 consent: CheckConsent, now: Date = Date()) {
        removeExpired(at: now)
        guard consent.links else { return }
        for code in codes where code.analysis.hasWebDestination && !code.analysis.containsSecrets {
            guard code.stability.isSteady(at: now), models[code.analysis.raw]?.attemptedCloud != true else { continue }
            let scene = sceneContainsPrivateCodes ? nil : code.observation.scene
            guard consent.allowsCheck(for: code.analysis, hasScene: scene != nil) else { continue }
            let limitations = sceneContainsPrivateCodes
                ? [L10n.text("The surroundings photo stayed on this iPhone because it contains a private code.")] : []
            _ = result(for: code.analysis, scene: scene, limitations: limitations, using: client, consent: consent, now: now)
        }
    }

    func revokeConsent() {
        for model in models.values { model.cancel() }
    }

    func removeExpired(at now: Date = Date()) {
        for (raw, date) in createdAt where now.timeIntervalSince(date) >= Self.lifetime {
            remove(raw)
        }
    }

    private func remove(_ raw: String) {
        models.removeValue(forKey: raw)?.cancel()
        createdAt.removeValue(forKey: raw)
    }
}
