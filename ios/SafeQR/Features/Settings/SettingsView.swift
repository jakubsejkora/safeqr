import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var preferences = services.preferences
        NavigationStack {
            Form {
                Section {
                    Toggle(L10n.text("Deep checks for links"), isOn: $preferences.deepChecksEnabled)
                    Toggle(L10n.text("Check the surroundings photo"), isOn: $preferences.sceneChecksEnabled)
                        .disabled(!preferences.deepChecksEnabled)
                } header: { Text(L10n.text("Deep checks")) } footer: {
                    Text(L10n.text("Links are checked on Safe QR servers in the EU. Photo checks also send the code’s contents, including payment details. Photos are never stored. Wi-Fi passwords, login codes and personal records stay on this iPhone."))
                }
                Section {
                    Toggle(L10n.text("Save scan history"), isOn: $preferences.historyEnabled)
                        .disabled(services.history == nil)
                    NavigationLink { HistoryView() } label: { Label(L10n.text("Scan history"), systemImage: "clock") }
                } header: { Text(L10n.text("Only on this iPhone")) } footer: {
                    Text(services.history == nil
                         ? L10n.text("History is unavailable on this device. Scanning still works.")
                         : L10n.text("Off by default. Saves the code type, date and score on this iPhone. No raw codes, photos or passwords. Turning this off keeps existing entries until you delete them."))
                }
                Section(L10n.text("Your preferences")) {
                    Button { openSettings() } label: {
                        Label(L10n.text("App language"), systemImage: "globe")
                    }
                    NavigationLink { PrivacyView() } label: {
                        Label(L10n.text("Privacy & AI"), systemImage: "hand.raised")
                    }
                    NavigationLink { AboutView() } label: {
                        Label(L10n.text("About Safe QR"), systemImage: "info.circle")
                    }
                }
                #if DEBUG
                Section {
                    Toggle(L10n.text("Demo deep checks"), isOn: $preferences.demoEnabled)
                } header: { Text(L10n.text("Developer demo")) } footer: {
                    Text(L10n.text("Uses clearly labelled sample evidence. No server is contacted. Deep-check consent still applies. Resets when the app closes."))
                }
                #endif
            }
            .navigationTitle(L10n.text("Settings"))
        }
    }
}
