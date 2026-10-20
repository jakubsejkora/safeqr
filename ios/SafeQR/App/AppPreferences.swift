import Foundation
import Observation

@MainActor @Observable
final class AppPreferences {
    private let defaults: UserDefaults

    var finishedOnboarding: Bool { didSet { defaults.set(finishedOnboarding, forKey: "onboarding") } }
    var deepChecksEnabled: Bool { didSet { defaults.set(deepChecksEnabled, forKey: "deepChecks") } }
    var sceneChecksEnabled: Bool { didSet { defaults.set(sceneChecksEnabled, forKey: "sceneChecks") } }
    var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var historyEnabled: Bool { didSet { defaults.set(historyEnabled, forKey: "history") } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .graphite
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .automatic
        finishedOnboarding = defaults.bool(forKey: "onboarding")
        deepChecksEnabled = defaults.bool(forKey: "deepChecks")
        sceneChecksEnabled = defaults.bool(forKey: "sceneChecks")
        historyEnabled = defaults.bool(forKey: "history")
    }

    var consent: CheckConsent {
        CheckConsent(links: deepChecksEnabled, surroundings: deepChecksEnabled && sceneChecksEnabled)
    }
}
