import SwiftUI

struct SettingsSections: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var preferences = services.preferences
        Group {
            Section {
                Toggle(L10n.text("Deep checks for links"), isOn: $preferences.deepChecksEnabled)
                Toggle(L10n.text("Check the surroundings photo"), isOn: $preferences.sceneChecksEnabled)
                    .disabled(!preferences.deepChecksEnabled)
            } header: { Text(L10n.text("Deep checks")) } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("Deep checks send the code, including any payment details. Photo checks also send its surroundings. Recognized private codes stay on this iPhone."))
                    Text(L10n.text("Servers and storage are in AWS Frankfurt (eu-central-1). Amazon Bedrock AI may also process requests in other AWS regions within the EU."))
                    Text(L10n.text("Photos are kept briefly in private encrypted storage. We delete them after the check. A one-day cleanup rule is the backup if deletion fails. Actual deletion can take longer."))
                    Text(L10n.text("Check results become unavailable after 24 hours. Deleting stored data can take longer."))
                }
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
        }
    }
}
