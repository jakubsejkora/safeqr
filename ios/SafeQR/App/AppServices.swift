import Foundation
import Observation
import SafeQRKit

@MainActor @Observable
final class AppServices {
    let preferences: AppPreferences
    let camera: any CameraSource
    let navigation = AppNavigation()
    let checks = ScanChecks()
    let history: HistoryStore?
    let guides: GuideLibrary
    let checker: any CloudChecking

    init(defaults: UserDefaults = .standard, cloud: (any CloudChecking)? = nil,
         camera: (any CameraSource)? = nil, inMemoryHistory: Bool = false) {
        preferences = AppPreferences(defaults: defaults)
        self.camera = camera ?? CameraModel()
        history = try? HistoryStore(inMemory: inMemoryHistory)
        guides = GuideLibrary()
        checker = cloud ?? Self.cloudClient()
    }

    static func cloudClient() -> CloudClient {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SafeQRAPIBaseURL") as? String
        let baseURL = URL(string: configured ?? "https://api.bezpecneqr.cz")
        return CloudClient(baseURL: baseURL)
    }

    func present(_ analysis: CodeAnalysis, scene: ScenePhoto?, limitations: [String] = []) async {
        guard navigation.result == nil else { return }
        let model = checks.result(for: analysis, scene: scene, limitations: limitations,
                                  using: checker, consent: preferences.consent)
        await camera.freeze()
        guard navigation.result == nil else { return }
        navigation.result = ResultPresentation(model: model)
    }
}
