import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

@Suite @MainActor
struct ScanPresentationTests {
    private let start = Date(timeIntervalSince1970: 100)

    @Test func aSingleCodeOpensOnlyAfterItsSteadyLock() {
        let code = tracked("https://example.com")
        var gate = ScanPresentationGate()
        let early = gate.decision(for: [code], at: start.addingTimeInterval(0.7))
        let locked = gate.decision(for: [code], at: start.addingTimeInterval(0.8))
        #expect(early == nil)
        #expect(locked == .single(code.id))
    }

    @Test func dismissalRequiresAFullSecondOutOfViewAndADifferentCodeCanOpen() {
        let code = tracked("https://example.com")
        let other = tracked("https://other.example")
        var gate = ScanPresentationGate()
        gate.presented([code])
        gate.resumed()
        let same = gate.decision(for: [code], at: start.addingTimeInterval(60))
        let different = gate.decision(for: [other], at: start.addingTimeInterval(61))
        let briefAbsence = gate.decision(for: [code], at: start.addingTimeInterval(61.9))
        #expect(same == nil)
        #expect(different == .single(other.id))
        #expect(briefAbsence == nil)
        _ = gate.decision(for: [], at: start.addingTimeInterval(62))
        _ = gate.decision(for: [], at: start.addingTimeInterval(63))
        let returned = gate.decision(for: [code], at: start.addingTimeInterval(63.1))
        #expect(returned == .single(code.id))
    }

    @Test func frozenTimeDoesNotCountAsAbsence() {
        let code = tracked("https://example.com")
        var gate = ScanPresentationGate()
        gate.presented([code])
        _ = gate.decision(for: [], at: start.addingTimeInterval(1))
        gate.resumed()
        _ = gate.decision(for: [], at: start.addingTimeInterval(60))
        let returned = gate.decision(for: [code], at: start.addingTimeInterval(60.5))
        #expect(returned == nil)
    }

    @Test func anImportedResultAlsoSuppressesTheSamePayloadInTheCamera() {
        let code = tracked("https://example.com")
        var gate = ScanPresentationGate()
        gate.presented(code.analysis.raw)
        gate.resumed()
        let same = gate.decision(for: [code], at: start.addingTimeInterval(60))
        #expect(same == nil)
    }

    @Test func multipleCodesUseTheChooserEvenWhileMovingOrWithIdenticalPayloads() {
        let first = tracked("https://example.com")
        var second = tracked("https://example.com")
        second.stability = CodeStability(bounds: second.bounds, now: start.addingTimeInterval(1))
        var gate = ScanPresentationGate()
        let moving = gate.decision(for: [first, second], at: start.addingTimeInterval(1.2))
        let steady = gate.decision(for: [first, second], at: start.addingTimeInterval(2))
        #expect(moving == .chooser)
        #expect(steady == .chooser)
        gate.presented([first, second])
        gate.resumed()
        let dismissed = gate.decision(for: [first, second], at: start.addingTimeInterval(60))
        #expect(dismissed == nil)
    }

    @Test func stickerWarningRequiresExactlyTwoNearbyCodes() {
        let first = tracked("https://example.com", x: 0.2)
        let nearby = tracked("https://other.example", x: 0.41)
        let distant = tracked("https://distant.example", x: 0.8)
        #expect(ScanPresentationGate.mayBeOverlaid([first, nearby]))
        #expect(!ScanPresentationGate.mayBeOverlaid([first, distant]))
        #expect(!ScanPresentationGate.mayBeOverlaid([first, nearby, distant]))
    }

    @Test func sharingUsesTheOriginalTextAndSecretsKeepOnlyLocalCopy() throws {
        let publicCode = CodeInspector().inspect("http://www.vodafone.cz")
        let publicResult = ResultModel(analysis: publicCode, scene: nil)
        #expect(publicResult.shareText == publicCode.raw)
        for raw in ["otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP",
                    "WIFI:T:WPA;S:Home;P:private;;", "https://example.com?access_token=private"] {
            let result = ResultModel(analysis: CodeInspector().inspect(raw), scene: nil)
            #expect(result.shareText == nil)
            let copy = try #require(result.copyAction)
            #expect(copy.kind == .copy(raw))
        }
    }

    #if DEBUG
    @Test func automaticPresentationFreezesTheCameraAndReusesTheExistingCheck() async throws {
        let suite = "cz.safeqr.presentation-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let camera = ScannerFixture(mode: .locked)
        let services = AppServices(defaults: defaults, cloud: PreviewCloudClient(), camera: camera, inMemoryHistory: true)
        let code = try #require(camera.codes.first)
        let existing = services.checks.result(for: code.analysis, scene: nil, using: services.checker,
                                              consent: services.preferences.consent)
        await services.present(code.analysis, scene: code.observation.scene)
        #expect(camera.isFrozen)
        #expect(camera.codes.first?.id == code.id)
        #expect(services.navigation.result?.model === existing)
        services.navigation.result = nil
        await camera.start()
        #expect(!camera.isFrozen)
    }
    #endif

    private func tracked(_ raw: String, x: Double = 0.2) -> TrackedCode {
        let bounds = CodeBounds(rect: CGRect(x: x, y: 0.2, width: 0.2, height: 0.2))
        var tracked = TrackedCode(observation: CameraObservation(
            code: ScannedCode(raw: raw, symbology: .qr, bounds: bounds), scene: nil,
            frameSize: CGSize(width: 1000, height: 1000), ultraBounds: bounds, ultraSize: CGSize(width: 1000, height: 1000)))
        tracked.stability = CodeStability(bounds: bounds, now: start)
        return tracked
    }
}
