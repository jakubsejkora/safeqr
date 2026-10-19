import Foundation
import Observation

@MainActor @Observable
final class AppServices {
    let preferences: AppPreferences
    let camera = CameraModel()
    let history: HistoryStore?
    let guides: GuideLibrary
    private let cloud: any CloudChecking

    init(defaults: UserDefaults = .standard, cloud: (any CloudChecking)? = nil, inMemoryHistory: Bool = false) {
        preferences = AppPreferences(defaults: defaults)
        #if DEBUG
        if let screen = DebugLaunch.screen { preferences.finishedOnboarding = screen != "onboarding" }
        #endif
        history = try? HistoryStore(inMemory: inMemoryHistory)
        guides = GuideLibrary()
        let configured = Bundle.main.object(forInfoDictionaryKey: "SafeQRAPIBaseURL") as? String
        let baseURL = URL(string: configured ?? "https://api.safeqr.cz")
        self.cloud = cloud ?? CloudClient(baseURL: baseURL)
    }

    var checker: any CloudChecking {
        #if DEBUG
        if preferences.demoEnabled { return PreviewCloudClient() }
        #endif
        return cloud
    }
}
