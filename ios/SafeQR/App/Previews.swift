#if DEBUG
import SwiftUI

@MainActor private func previewServices() -> AppServices {
    let defaults = UserDefaults(suiteName: "cz.safeqr.previews") ?? UserDefaults()
    let services = AppServices(defaults: defaults, cloud: PreviewCloudClient(), inMemoryHistory: true)
    services.preferences.finishedOnboarding = true
    return services
}

#Preview("Scan") {
    ScanView().environment(previewServices()).tint(AppStyle.accent)
}

#Preview("Onboarding") {
    OnboardingView().environment(previewServices()).tint(AppStyle.accent)
}

#Preview("Help") {
    HelpView().environment(previewServices()).tint(AppStyle.accent)
}
#endif
