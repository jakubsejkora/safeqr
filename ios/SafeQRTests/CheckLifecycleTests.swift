import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

@Suite @MainActor
struct CheckLifecycleTests {
    private let consent = CheckConsent(links: true, surroundings: true)

    @Test func aPendingLinkNeverAllowsAHandoff() async throws {
        let analysis = CodeInspector().inspect("https://example.com")
        let model = ResultModel(analysis: analysis, scene: nil)
        #expect(model.linkPending)
        #expect(!model.allowsHandoff)
        let client = SuspendedCheck()
        model.start(using: client, consent: consent)
        await client.waitForStart()
        #expect(model.checking)
        #expect(model.linkPending)
        #expect(!model.allowsHandoff)
        await client.finish(score: 10)
        await model.run(using: client, consent: consent)
        #expect(!model.linkPending)
        #expect(model.allowsHandoff)
        #expect(model.handoffLevel == .safe)
    }

    @Test func failedAndDisabledChecksRequireCautionWithoutChangingDeviceScore() async {
        let analysis = CodeInspector().inspect("https://example.com")
        let offline = ResultModel(analysis: analysis, scene: nil)
        await offline.run(using: UnavailableCheck(), consent: CheckConsent(links: false, surroundings: false))
        #expect(offline.destinationUnchecked)
        #expect(offline.handoffLevel == .caution)
        #expect(offline.assessment.score == analysis.assessment.score)
        #expect(offline.allowsHandoff)
        let failed = ResultModel(analysis: analysis, scene: nil)
        await failed.run(using: UnavailableCheck(), consent: consent)
        #expect(failed.destinationUnchecked)
        #expect(failed.handoffLevel == .caution)
        #expect(failed.limitations.contains(L10n.text("The destination could not be checked. Be careful if you continue.")))
        let dangerous = ResultModel(analysis: CodeInspector().inspect("https://xn--pple-43d.test"), scene: nil)
        await dangerous.run(using: UnavailableCheck(), consent: consent)
        #expect(dangerous.handoffLevel == .danger)
    }

    @Test func aSteadyLinkSharesItsCheckAndReleasesTheUploadPhoto() async throws {
        let client = SuspendedCheck()
        let checks = ScanChecks()
        let code = tracked("https://example.com", jpeg: try PhotoFixture.jpeg(["https://example.com"]))
        checks.observe([code], sceneContainsPrivateCodes: false, using: client, consent: consent, now: Date().addingTimeInterval(0.4))
        #expect(checks.models.isEmpty)
        checks.observe([code], sceneContainsPrivateCodes: false, using: client, consent: consent, now: Date().addingTimeInterval(0.9))
        let locked = try #require(checks.models[code.analysis.raw])
        await client.waitForStart()
        let selected = checks.result(for: code.analysis, scene: nil, using: client, consent: consent)
        #expect(selected === locked)
        #expect(selected.scene == nil)
        #expect(await client.photo?.image == code.observation.scene?.jpeg.base64EncodedString())
        checks.observe([code], sceneContainsPrivateCodes: false, using: client, consent: consent, now: Date().addingTimeInterval(5))
        #expect(await client.calls == 1)
        #expect(selected.linkPending)
        let sheetObserver = Task { await selected.run(using: client, consent: consent) }
        sheetObserver.cancel()
        #expect(selected.checking)
        await client.finish(score: 85)
        await sheetObserver.value
        await selected.run(using: client, consent: consent)
        #expect(locked.assessment.level == .danger)
        #expect(locked.verdict != nil)
        #expect(checks.result(for: code.analysis, scene: nil, using: client, consent: consent) === locked)
        #expect(await client.calls == 1)
    }

    @Test func automaticChecksRequireConsentAndKeepSecretPayloadsAndPhotosLocal() async throws {
        let checks = ScanChecks()
        let client = SuspendedCheck()
        let secret = tracked("https://example.com?access_token=private")
        checks.observe([secret], sceneContainsPrivateCodes: true, using: client, consent: consent, now: Date().addingTimeInterval(2))
        #expect(checks.models.isEmpty)
        let publicCode = tracked("https://example.com")
        checks.observe([publicCode], sceneContainsPrivateCodes: false, using: client,
                       consent: CheckConsent(links: false, surroundings: false), now: Date().addingTimeInterval(2))
        #expect(checks.models.isEmpty)
        checks.observe([publicCode], sceneContainsPrivateCodes: true, using: client, consent: consent, now: Date().addingTimeInterval(2))
        await client.waitForStart()
        let model = try #require(checks.models[publicCode.analysis.raw])
        #expect(model.scene == nil)
        #expect(await client.photo == nil)
        await client.finish(score: 10)
        await model.run(using: client, consent: consent)
    }

    @Test func enablingConsentCanStartAPreviouslyLocalResultOnce() async {
        let client = SuspendedCheck()
        let checks = ScanChecks()
        let code = tracked("https://example.com")
        let local = checks.result(for: code.analysis, scene: nil, using: client,
                                  consent: CheckConsent(links: false, surroundings: false))
        #expect(local.destinationUnchecked)
        checks.observe([code], sceneContainsPrivateCodes: false, using: client, consent: consent, now: Date().addingTimeInterval(2))
        await client.waitForStart()
        #expect(local.linkPending)
        #expect(!local.allowsHandoff)
        #expect(local.scene == nil)
        await client.finish(score: 10)
        await local.run(using: client, consent: consent)
        #expect(!local.destinationUnchecked)
        #expect(local.cloudLimitation == nil)
        #expect(await client.calls == 1)
    }

    @Test func movementResetsTheLockAndSmallJitterDoesNot() {
        let now = Date(timeIntervalSince1970: 100)
        let bounds = CodeBounds(rect: CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2))
        var lock = CodeStability(bounds: bounds, now: now)
        lock.observe(CodeBounds(rect: CGRect(x: 0.21, y: 0.2, width: 0.2, height: 0.2)), at: now.addingTimeInterval(0.7))
        #expect(lock.isSteady(at: now.addingTimeInterval(0.8)))
        lock.observe(CodeBounds(rect: CGRect(x: 0.3, y: 0.2, width: 0.2, height: 0.2)), at: now.addingTimeInterval(1))
        #expect(!lock.isSteady(at: now.addingTimeInterval(1.7)))
        #expect(lock.isSteady(at: now.addingTimeInterval(1.9)))
    }

    @Test func theStartBudgetRespectsRollingMinutesAndServerCooldown() {
        var budget = CheckStartBudget()
        let now = Date(timeIntervalSince1970: 100)
        for _ in 0..<12 { #expect(budget.reserve(at: now) == 0) }
        #expect(budget.reserve(at: now.addingTimeInterval(1)) == 59)
        #expect(budget.reserve(at: now.addingTimeInterval(60)) == 0)
        budget.postpone(until: now.addingTimeInterval(120))
        #expect(budget.reserve(at: now.addingTimeInterval(61)) == 59)
        #expect(budget.reserve(at: now.addingTimeInterval(120)) == 0)
    }

    @Test func cacheExpiresWithoutExtendingOnReuseAndEvictsOldestEntries() {
        let checks = ScanChecks()
        let now = Date()
        let disabled = CheckConsent(links: false, surroundings: false)
        let analysis = CodeInspector().inspect("https://example.com")
        let first = checks.result(for: analysis, scene: nil, using: UnavailableCheck(), consent: disabled, now: now)
        let reused = checks.result(for: analysis, scene: nil, using: UnavailableCheck(), consent: disabled, now: now.addingTimeInterval(599))
        #expect(first === reused)
        checks.removeExpired(at: now.addingTimeInterval(600))
        #expect(checks.models.isEmpty)
        let renewed = checks.result(for: analysis, scene: nil, using: UnavailableCheck(), consent: disabled, now: now.addingTimeInterval(600))
        #expect(renewed !== first)
        for index in 1...ScanChecks.capacity {
            _ = checks.result(for: CodeInspector().inspect("https://example.com/\(index)"), scene: nil,
                              using: UnavailableCheck(), consent: disabled, now: now.addingTimeInterval(600 + Double(index)))
        }
        #expect(checks.models.count == ScanChecks.capacity)
        #expect(checks.models[analysis.raw] == nil)
        checks.removeExpired(at: now.addingTimeInterval(1_220))
        #expect(checks.models.isEmpty)
    }

    @Test func unsafePhotoIsDroppedBeforeTheClientReceivesARequest() async throws {
        let selected = "https://example.com"
        let jpeg = try PhotoFixture.jpeg([selected, "WIFI:T:WPA;S:Home;P:private;;"])
        let model = ResultModel(analysis: CodeInspector().inspect(selected),
                                scene: ScenePhoto(jpeg: jpeg, source: .ultraWideCamera, bounds: nil))
        let client = SuspendedCheck()
        model.start(using: client, consent: consent)
        await client.waitForStart()
        #expect(await client.photo == nil)
        #expect(model.scene == nil)
        #expect(model.extraLimitations.contains(L10n.text("The surroundings photo was not sent because it could not be safely checked for private codes.")))
        await client.finish(score: 10)
        await model.run(using: client, consent: consent)
    }

    private func tracked(_ raw: String, jpeg: Data = Data([1, 2, 3])) -> TrackedCode {
        let bounds = CodeBounds(rect: CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.2))
        return TrackedCode(observation: CameraObservation(code: ScannedCode(raw: raw, symbology: .qr, bounds: bounds),
            scene: ScenePhoto(jpeg: jpeg, source: .photo, bounds: bounds),
            frameSize: CGSize(width: 1000, height: 1000), ultraBounds: bounds, ultraSize: CGSize(width: 1000, height: 1000)))
    }
}

private actor SuspendedCheck: CloudChecking {
    private var continuation: CheckedContinuation<CloudVerdict, Never>?
    private var started: CheckedContinuation<Void, Never>?
    private(set) var calls = 0
    private(set) var photo: CheckRequest.Scene?

    func waitForStart() async {
        if calls == 0 { await withCheckedContinuation { started = $0 } }
    }

    func check(_ makeRequest: @escaping CheckRequestProvider, onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        photo = await makeRequest()?.scene
        calls += 1
        return await withCheckedContinuation {
            continuation = $0
            started?.resume()
            started = nil
        }
    }

    func finish(score: Int) {
        continuation?.resume(returning: CloudVerdict(score: score, level: .known(.init(score: score)), headline: "Checked.",
            findings: [], consequences: [], limitations: [], link: nil, scene: nil, intel: nil, models: []))
        continuation = nil
    }
}

private struct UnavailableCheck: CloudChecking {
    func check(_ makeRequest: @escaping CheckRequestProvider, onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        throw CloudError.unavailable
    }
}
