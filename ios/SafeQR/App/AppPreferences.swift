import Foundation
import Observation

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var finishedOnboarding: Bool { didSet { defaults.set(finishedOnboarding, forKey: "onboarding") } }
    var deepChecksEnabled: Bool { didSet { defaults.set(deepChecksEnabled, forKey: "deepChecks") } }
    var sceneChecksEnabled: Bool { didSet { defaults.set(sceneChecksEnabled, forKey: "sceneChecks") } }
    var historyEnabled: Bool { didSet { defaults.set(historyEnabled, forKey: "history") } }
    #if DEBUG
    var demoEnabled = false
    #endif

    init(defaults: UserDefaults) {
        self.defaults = defaults
        finishedOnboarding = defaults.bool(forKey: "onboarding")
        deepChecksEnabled = defaults.bool(forKey: "deepChecks")
        sceneChecksEnabled = defaults.bool(forKey: "sceneChecks")
        historyEnabled = defaults.bool(forKey: "history")
    }

    var consent: CheckConsent {
        CheckConsent(links: deepChecksEnabled, surroundings: deepChecksEnabled && sceneChecksEnabled)
    }
}
