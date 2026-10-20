#if DEBUG
import Observation
import SafeQRKit
import SwiftUI

@MainActor @Observable
final class DebugLaunchConfiguration {
    let options: DebugLaunch
    let sample: DebugSample?
    let scannerMode: ScannerFixture.Mode?
    var demoEnabled = false

    init(_ options: DebugLaunch) {
        self.options = options
        sample = options.screen.flatMap(DebugSample.init(rawValue:))
        scannerMode = options.screen.flatMap(ScannerFixture.Mode.init(rawValue:))
    }

    func makeServices(defaults: UserDefaults = .standard, inMemoryHistory: Bool = false) -> AppServices {
        let services = AppServices(defaults: defaults,
                                   cloud: DebugCloudClient(configuration: self, live: AppServices.cloudClient()),
                                   camera: scannerMode.map { ScannerFixture(mode: $0) }, inMemoryHistory: inMemoryHistory)
        if let theme = options.theme { services.preferences.theme = theme }
        if let appearance = options.appearance { services.preferences.appearance = appearance }
        if let zoom = options.zoom { services.camera.selectZoom(zoom) }
        if let screen = options.screen {
            services.preferences.finishedOnboarding = screen != "onboarding"
            services.preferences.deepChecksEnabled = ["training", "http", "scannerChecking", "scannerDanger"].contains(screen) && options.liveCheck
            services.preferences.sceneChecksEnabled = services.preferences.deepChecksEnabled && options.liveScene
            if screen == "help" || screen == "guide" { services.navigation.tab = .help }
            if screen == "settings" { services.navigation.tab = .settings }
            if screen == "guide", let guide = services.guides.guides.first(where: { $0.id == "recovery-1" }) {
                services.navigation.guides = [guide]
            }
        }
        if sample != nil { services.navigation.resultDetent = options.medium ? .medium : .large }
        return services
    }

    func presentSample(in services: AppServices) {
        guard let sample else { return }
        present(sample, in: services, scene: sample == .training && options.liveScene ? ScannerFixture.scene : nil)
    }

    func present(_ sample: DebugSample, in services: AppServices, scene: ScenePhoto? = nil) {
        services.present(CodeInspector(locale: L10n.locale).inspect(sample.raw), scene: scene)
    }

    func prepareConfirmation(in services: AppServices) async {
        guard options.confirmation, let result = services.navigation.result else { return }
        do { try await Task.sleep(for: .milliseconds(500)) }
        catch { return }
        guard services.navigation.result === result, result.model.allowsHandoff else { return }
        result.selectedAction = result.model.actions.first(where: \.isHandoff)
    }
}
#endif
