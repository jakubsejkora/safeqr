import Foundation
import Observation
import SafeQRKit

@MainActor @Observable
final class ResultModel: Identifiable {
    let analysis: CodeAnalysis
    private(set) var scene: ScenePhoto?
    private(set) var extraLimitations: [String]
    nonisolated var id: UUID { analysis.id }
    private(set) var assessment: RiskAssessment
    private(set) var steps: [CheckStep] = []
    private(set) var verdict: CloudVerdict?
    private(set) var checking = false
    private(set) var elapsedSeconds = 0
    private(set) var cloudLimitation: String?
    private(set) var finished = false
    @ObservationIgnored private var checkTask: Task<Void, Never>?
    private(set) var attemptedCloud = false

    var linkPending: Bool { analysis.hasWebDestination && !finished }
    var destinationUnchecked: Bool { analysis.hasWebDestination && finished && verdict == nil }
    var handoffLevel: RiskLevel {
        (destinationUnchecked || linkPending) && assessment.level == .safe ? .caution : assessment.level
    }
    var allowsHandoff: Bool { !linkPending }

    init(analysis: CodeAnalysis, scene: ScenePhoto?, extraLimitations: [String] = []) {
        self.analysis = analysis
        self.scene = scene
        self.extraLimitations = extraLimitations
        assessment = analysis.assessment
    }

    var headline: String {
        guard let verdict, verdict.score >= analysis.assessment.floor else { return analysis.content.summary }
        let plain = verdict.headline.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        if plain.localizedCaseInsensitiveCompare(assessment.level.title) == .orderedSame {
            return verdict.findings.first?.title ?? analysis.content.summary
        }
        return verdict.headline
    }

    var limitations: [String] {
        var seen = Set<String>()
        return (assessment.limitations + extraLimitations + [cloudLimitation, destinationUnchecked ? L10n.text("The destination could not be checked. Be careful if you continue.") : nil].compactMap { $0 }).filter { seen.insert($0).inserted }
    }

    func prepare(scene: ScenePhoto?, limitations: [String]) {
        guard !attemptedCloud else { return }
        self.scene = scene
        extraLimitations = limitations
    }

    func run(using client: any CloudChecking, consent: CheckConsent) async {
        start(using: client, consent: consent)
        await checkTask?.value
    }

    func start(using client: any CloudChecking, consent: CheckConsent) {
        guard checkTask == nil, !attemptedCloud else { return }
        guard let request = consent.request(for: analysis, scene: scene) else {
            cloudLimitation = consent.links
                ? L10n.text("This code was checked only on this iPhone. No code or photo was sent.")
                : L10n.text("Deep checks are off. Websites and surroundings were not checked online.")
            finished = true
            return
        }
        cloudLimitation = nil
        finished = false
        attemptedCloud = true
        checking = true
        // The check belongs to the scan session, so opening or dismissing a sheet cannot restart it.
        checkTask = Task { await execute(request, using: client) }
    }

    func cancel() { checkTask?.cancel() }

    private func execute(_ request: CheckRequest, using client: any CloudChecking) async {
        let startedAt = ContinuousClock.now
        defer {
            elapsedSeconds = Int(startedAt.duration(to: .now).components.seconds)
            checking = false
            finished = true
        }
        do {
            let result = try await client.check(request) { [weak self] steps in self?.steps = steps }
            try Task.checkCancellation()
            verdict = result
            assessment = analysis.assessment.merged(with: result.assessment)
        } catch is CancellationError {
            cloudLimitation = L10n.text("The deep check was stopped. The result from this iPhone is still available.")
        } catch CloudError.rateLimited {
            cloudLimitation = L10n.text("Too many deep checks are running. The destination could not be checked.")
        } catch CloudError.invalidResponse {
            cloudLimitation = L10n.text("Some deep-check results could not be read. Only the checks on this iPhone are shown.")
        } catch {
            cloudLimitation = L10n.text("The deep check is unavailable. Only the checks on this iPhone are shown. Try again later.")
        }
    }
}
