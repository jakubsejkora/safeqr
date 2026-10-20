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
    var verdictAnnouncement: String {
        linkPending ? L10n.text("Checking the link…") : "\(assessment.level.title). \(headline)"
    }

    var shareText: String? {
        guard !analysis.containsSecrets else { return nil }
        return actions.compactMap { action in
            if case .share(let text) = action.kind { return text }
            return nil
        }.first
    }

    var copyAction: CodeAction? {
        actions.first { if case .copy = $0.kind { return true }; return false }
    }

    var secureURL: URL? {
        guard finished, !checking, let verdict, verdict.isValid,
              case .link(let original) = analysis.content.payload,
              let hops = verdict.link?.hops else { return nil }
        return SecureLinkUpgrade.destination(for: original, hops: hops)
    }

    var actions: [CodeAction] {
        guard let secureURL, case .link(let original) = analysis.content.payload else { return analysis.actions }
        return analysis.actions.map { action in
            guard case .open(let url) = action.kind, url == original else { return action }
            let confirmation = action.requiredConfirmation
            return CodeAction(id: action.id, kind: .open(secureURL), title: action.title, isPrimary: action.isPrimary,
                              confirmation: Confirmation(title: confirmation.title,
                                  message: L10n.format("Your browser will open %@.", secureURL.absoluteString),
                                  confirmTitle: confirmation.confirmTitle, isRisky: confirmation.isRisky))
        }
    }

    var confirmationReason: String? {
        if destinationUnchecked { return L10n.text("The destination could not be checked. Be careful if you continue.") }
        return assessment.findings.first { secureURL == nil || $0.id != "link.http" }?.title
    }

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
        guard consent.allowsCheck(for: analysis, hasScene: scene != nil) else {
            scene = nil
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
        checkTask = Task { await execute(using: client, consent: consent) }
    }

    func cancel() {
        scene = nil
        checkTask?.cancel()
    }

    private func makeRequest(consent: CheckConsent) async -> CheckRequest? {
        var photo = consent.surroundings ? scene : nil
        scene = nil
        if let candidate = photo, !(await ScenePrivacy.allowsUpload(candidate.jpeg, selectedPayload: analysis.raw)) {
            photo = nil
            extraLimitations.append(L10n.text("The surroundings photo was not sent because it could not be safely checked for private codes."))
        }
        guard !Task.isCancelled else { return nil }
        return consent.request(for: analysis, scene: photo)
    }

    private func execute(using client: any CloudChecking, consent: CheckConsent) async {
        let startedAt = ContinuousClock.now
        defer {
            elapsedSeconds = Int(startedAt.duration(to: .now).components.seconds)
            checking = false
            finished = true
            scene = nil
        }
        do {
            let result = try await client.check({ [weak self] in await self?.makeRequest(consent: consent) }) {
                [weak self] steps in self?.steps = steps
            }
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
