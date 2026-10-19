import Foundation
import Observation
import SafeQRKit

@MainActor @Observable
final class ResultModel: Identifiable {
    let analysis: CodeAnalysis
    let scene: ScenePhoto?
    let extraLimitations: [String]
    nonisolated var id: UUID { analysis.id }
    private(set) var assessment: RiskAssessment
    private(set) var steps: [CheckStep] = []
    private(set) var verdict: CloudVerdict?
    private(set) var checking = false
    private(set) var cloudLimitation: String?
    private var started = false

    init(analysis: CodeAnalysis, scene: ScenePhoto?, extraLimitations: [String] = []) {
        self.analysis = analysis
        self.scene = scene
        self.extraLimitations = extraLimitations
        assessment = analysis.assessment
    }

    var headline: String {
        guard let verdict, verdict.score >= analysis.assessment.floor else { return analysis.content.summary }
        return verdict.headline
    }

    var limitations: [String] {
        var seen = Set<String>()
        return (assessment.limitations + extraLimitations + [cloudLimitation].compactMap { $0 }).filter { seen.insert($0).inserted }
    }

    func run(using client: any CloudChecking, consent: CheckConsent) async {
        guard !started else { return }
        started = true
        guard let request = consent.request(for: analysis, scene: scene) else {
            cloudLimitation = consent.links
                ? L10n.text("This code was checked only on this iPhone. No code or photo was sent.")
                : L10n.text("Deep checks are off. Websites and surroundings were not checked online.")
            return
        }
        checking = true
        defer { checking = false }
        do {
            let result = try await client.check(request) { [weak self] steps in self?.steps = steps }
            try Task.checkCancellation()
            verdict = result
            assessment = analysis.assessment.merged(with: result.assessment)
        } catch is CancellationError {
            cloudLimitation = L10n.text("The deep check was stopped. The result from this iPhone is still available.")
        } catch {
            cloudLimitation = L10n.text("The deep check is unavailable. Only the checks on this iPhone are shown. Try again later.")
        }
    }
}
