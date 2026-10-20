import SwiftUI

@main
struct SafeQRApp: App {
    @State private var services: AppServices
    #if DEBUG
    private let launch: DebugLaunchConfiguration
    #endif

    init() {
        #if DEBUG
        let launch = DebugLaunchConfiguration(DebugLaunch(arguments: ProcessInfo.processInfo.arguments))
        self.launch = launch
        _services = State(initialValue: launch.makeServices())
        #else
        _services = State(initialValue: AppServices())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                DebugRootView().environment(launch)
                #else
                RootView { ScanView(isSelected: $0) } settings: { SettingsSections() }
                #endif
            }
            .environment(services)
            .environment(\.appTheme, services.preferences.theme)
            .tint(services.preferences.theme.accent)
            .background(WindowAppearance(appearance: services.preferences.appearance, theme: services.preferences.theme))
        }
    }
}

struct RootView<Scanner: View, Settings: View>: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var scanner: (Bool) -> Scanner
    @ViewBuilder var settings: () -> Settings

    var body: some View {
        @Bindable var preferences = services.preferences
        @Bindable var navigation = services.navigation
        TabView(selection: $navigation.tab) {
            Tab(L10n.text("Scan"), systemImage: "qrcode.viewfinder", value: AppTab.scan) {
                NavigationStack { scanner(navigation.tab == .scan) }
            }
            Tab(L10n.text("Help"), systemImage: "questionmark.circle", value: AppTab.help) { HelpView() }
            Tab(L10n.text("Settings"), systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    Form { settings() }.navigationTitle(L10n.text("Settings"))
                }
            }
        }
        .fullScreenCover(isPresented: Binding(get: { !preferences.finishedOnboarding }, set: { _ in })) {
            OnboardingView()
        }
        .onChange(of: preferences.consent) { old, new in
            if (old.links && !new.links) || (old.surroundings && !new.surroundings) { services.checks.revokeConsent() }
        }
        .onChange(of: navigation.tab) { _, newTab in
            if newTab != .scan { services.camera.stop() }
            else if preferences.finishedOnboarding { Task { await services.camera.start() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { services.camera.stop() }
        }
    }
}
