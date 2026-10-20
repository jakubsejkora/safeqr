#if DEBUG
import Foundation
import SafeQRKit
import SwiftUI
import Testing
@testable import SafeQR

@Suite @MainActor
struct DebugLaunchTests {
    @Test func argumentsAreParsedWithoutReadingTheProcess() {
        #expect(DebugLaunch(arguments: []).screen == nil)
        #expect(DebugLaunch(arguments: ["--screen"]).screen == nil)
        #expect(DebugLaunch(arguments: ["--screen", "--medium"]).screen == nil)
        let options = DebugLaunch(arguments: ["--screen", "training", "--medium", "--live-check", "--live-scene",
                                              "--confirmation", "--scene", "--journey", "--sandbox"])
        #expect(options.screen == "training")
        #expect(options.medium && options.liveCheck && options.liveScene && options.confirmation)
        #expect(options.sections == ["journey", "sandbox", "scene"])
        #expect(!DebugLaunch(arguments: ["--confirmation"]).confirmation)
    }

    @Test(arguments: DebugSample.allCases)
    func everySampleStillUsesTheDeviceEngine(_ sample: DebugSample) throws {
        let configuration = configuration(sample.rawValue)
        let services = services(configuration)
        configuration.presentSample(in: services)
        let result = try #require(services.navigation.result)
        #expect(configuration.sample == sample)
        #expect(result.model.analysis.raw == sample.raw)
        #expect(result.model.analysis.assessment == CodeInspector(locale: L10n.locale).inspect(sample.raw).assessment)
        #expect(services.navigation.resultDetent == .large)
        #expect(!services.preferences.deepChecksEnabled)
    }

    @Test(arguments: ScannerFixture.Mode.allCases)
    func scannerModesInjectAWorkingCameraSource(_ mode: ScannerFixture.Mode) throws {
        let configuration = configuration(mode.rawValue)
        let services = services(configuration)
        let camera = try #require(services.camera as? ScannerFixture)
        #expect(camera.mode == mode)
        #expect(camera.state == .ready)
        #expect(camera.frame != nil)
        #expect(camera.codes.count == (mode == .idle ? 0 : 1))
        #expect(camera.codes.first?.analysis.raw == (mode == .idle ? nil : DebugSample.training.raw))
        #expect(services.navigation.result == nil)
        camera.toggleTorch()
        #expect(camera.torchEnabled)
        camera.stop()
        #expect(!camera.torchEnabled)
    }

    @Test func navigationAndConsentRemainExplicit() {
        for screen in ["onboarding", "scan", "help", "guide", "settings", "training", "http", "scannerIdle",
                       "scannerLocked", "scannerChecking", "scannerDanger"] {
            let configuration = configuration(screen, flags: ["--live-check", "--live-scene"])
            let services = services(configuration)
            #expect(services.preferences.finishedOnboarding == (screen != "onboarding"))
            #expect(services.navigation.tab == (["help", "guide"].contains(screen) ? .help : screen == "settings" ? .settings : .scan))
            #expect(services.navigation.guides.first?.id == (screen == "guide" ? "recovery-1" : nil))
            let live = ["training", "http", "scannerChecking", "scannerDanger"].contains(screen)
            #expect(services.preferences.consent == CheckConsent(links: live, surroundings: live))
        }
        let medium = services(configuration("payment", flags: ["--medium"]))
        #expect(medium.navigation.resultDetent == .medium)
        let sceneWithoutLinks = services(configuration("training", flags: ["--live-scene"]))
        #expect(!sceneWithoutLinks.preferences.consent.surroundings)
    }

    @Test func normalDebugLaunchPreservesPreferences() throws {
        let suite = "cz.safeqr.launch-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "onboarding")
        defaults.set(true, forKey: "deepChecks")
        let configuration = DebugLaunchConfiguration(DebugLaunch(arguments: []))
        let services = configuration.makeServices(defaults: defaults, inMemoryHistory: true)
        #expect(services.camera is CameraModel)
        #expect(services.preferences.finishedOnboarding)
        #expect(services.preferences.deepChecksEnabled)
        #expect(!configuration.demoEnabled)
        #expect(services.navigation.result == nil)
    }

    @Test func confirmationOpensWithoutPerformingTheAction() async throws {
        let configuration = configuration("premiumSMS", flags: ["--confirmation"])
        let services = services(configuration)
        configuration.presentSample(in: services)
        let result = try #require(services.navigation.result)
        await result.model.run(using: services.checker, consent: services.preferences.consent)
        await configuration.prepareConfirmation(in: services)
        #expect(result.selectedAction == result.model.analysis.actions.first(where: \.isHandoff))
        #expect(result.selectedAction != nil)
    }

    @Test func demoSelectionNeverContactsTheLiveClient() async throws {
        let configuration = configuration("training")
        let live = LaunchCheck()
        let client = DebugCloudClient(configuration: configuration, live: live)
        let request = CheckRequest(analysis: CodeInspector().inspect(DebugSample.training.raw), scene: nil)
        _ = try await client.check({ request }, onProgress: { _ in })
        #expect(await live.calls == 1)
        configuration.demoEnabled = true
        let demo = try await client.check({ request }, onProgress: { _ in })
        #expect(await live.calls == 1)
        #expect(demo.models == ["demo"])
        #expect(demo.score == request.device.score)
    }

    private func configuration(_ screen: String, flags: [String] = []) -> DebugLaunchConfiguration {
        DebugLaunchConfiguration(DebugLaunch(arguments: ["--screen", screen] + flags))
    }

    private func services(_ configuration: DebugLaunchConfiguration) -> AppServices {
        let suite = "cz.safeqr.launch-tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        return configuration.makeServices(defaults: defaults, inMemoryHistory: true)
    }
}

private actor LaunchCheck: CloudChecking {
    private(set) var calls = 0

    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        calls += 1
        let request = try #require(await makeRequest())
        return CloudVerdict(score: request.device.score, level: .known(.init(score: request.device.score)),
                            headline: "Test", findings: [], consequences: [], limitations: [],
                            link: nil, scene: nil, intel: nil, models: [])
    }
}
#endif
