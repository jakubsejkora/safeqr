import SwiftUI

@main
struct SafeQRApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            RootView().environment(services).tint(AppStyle.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.scan

    init() {
        #if DEBUG
        if let screen = DebugLaunch.screen {
            if screen == "help" || screen == "guide" { _tab = State(initialValue: .help) }
            if screen == "settings" { _tab = State(initialValue: .settings) }
        }
        #endif
    }

    var body: some View {
        @Bindable var preferences = services.preferences
        TabView(selection: $tab) {
            Tab(L10n.text("Scan"), systemImage: "qrcode.viewfinder", value: AppTab.scan) { ScanView(isSelected: tab == .scan) }
            Tab(L10n.text("Help"), systemImage: "questionmark.circle", value: AppTab.help) { HelpView() }
            Tab(L10n.text("Settings"), systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
        }
        .fullScreenCover(isPresented: Binding(get: { !preferences.finishedOnboarding }, set: { _ in })) {
            OnboardingView()
        }
        .onChange(of: preferences.consent) { old, new in
            if (old.links && !new.links) || (old.surroundings && !new.surroundings) { services.checks.revokeConsent() }
        }
        .onChange(of: tab) { _, newTab in
            if newTab != .scan { services.camera.stop() }
            else if preferences.finishedOnboarding { Task { await services.camera.start() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { services.camera.stop() }
        }

    }
}

enum AppTab: Hashable { case scan, help, settings }
