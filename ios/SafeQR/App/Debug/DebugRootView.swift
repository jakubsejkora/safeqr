#if DEBUG
import SwiftUI

struct DebugRootView: View {
    @Environment(AppServices.self) private var services
    @Environment(DebugLaunchConfiguration.self) private var launch
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var launched = false

    var body: some View {
        @Bindable var launch = launch
        RootView { selected in
            ScanView(isSelected: selected) { DebugResultView(presentation: $0, compact: $1) }
                .toolbar {
                    if launch.options.screen == nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(DebugSample.training.title) { present(.training) }
                                ForEach(DebugSample.Category.allCases) { category in
                                    Menu(category.title) {
                                        ForEach(DebugSample.allCases.filter { $0.category == category && $0 != .training }) { sample in
                                            Button(sample.title) { present(sample) }
                                        }
                                    }
                                }
                            } label: { Label(L10n.text("Sample codes"), systemImage: "ellipsis.circle") }
                            .accessibilityIdentifier("sample-codes")
                        }
                    }
                }
        } settings: {
            SettingsSections()
            Section {
                Toggle(L10n.text("Demo deep checks"), isOn: $launch.demoEnabled)
            } header: { Text(L10n.text("Developer demo")) } footer: {
                Text(L10n.text("Uses clearly labelled sample evidence. No server is contacted. Deep-check consent still applies. Resets when the app closes."))
            }
        }
        .task {
            guard !launched else { return }
            launched = true
            if typeSize.isAccessibilitySize { services.navigation.resultDetent = .large }
            await launch.presentSample(in: services)
        }
    }

    private func present(_ sample: DebugSample) {
        if typeSize.isAccessibilitySize { services.navigation.resultDetent = .large }
        Task { await launch.present(sample, in: services) }
    }
}
#endif
