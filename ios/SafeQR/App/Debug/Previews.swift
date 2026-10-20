#if DEBUG
import SwiftUI
import SafeQRKit

@MainActor private func previewServices() -> AppServices {
    let defaults = UserDefaults(suiteName: "cz.safeqr.previews") ?? UserDefaults()
    let services = AppServices(defaults: defaults, cloud: PreviewCloudClient(), inMemoryHistory: true)
    services.preferences.finishedOnboarding = true
    return services
}

#Preview("Scan") {
    NavigationStack { ScanView() }.environment(previewServices()).tint(AppStyle.accent)
}

#Preview("Onboarding") {
    OnboardingView().environment(previewServices()).tint(AppStyle.accent)
}

#Preview("Help") {
    HelpView().environment(previewServices()).tint(AppStyle.accent)
}
#Preview("Payloads") {
    ScrollView {
        VStack(alignment: .leading, spacing: 40) {
            ForEach(DebugSample.allCases) { sample in
                VStack(alignment: .leading, spacing: 12) {
                    Text(sample.title).font(.headline)
                    PayloadView(content: CodeInspector(locale: L10n.locale).inspect(sample.raw).content)
                }
            }
        }.padding()
    }
}
#endif
