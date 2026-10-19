import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section(L10n.text("On your iPhone")) {
                Text(L10n.text("Every code is read and checked on your iPhone first. Camera images are held in memory and are not saved to your photo library."))
                Text(L10n.text("History is off by default. If enabled, only the code type, time and score are saved locally. History is excluded from backups. Delete individual entries or clear them all in Settings."))
            }
            Section(L10n.text("What a deep check sends")) {
                Text(L10n.text("With your permission, Safe QR sends the decoded link, language, device score and warning identifiers. If photo checks are on, it also sends a photo and the code’s position in it. For a payment code, this can include the recipient and amount."))
                Text(L10n.text("Wi-Fi passwords, login and eSIM codes, contacts, events, phone numbers, messages and email details stay on this iPhone. The app sends no location from GPS."))
                Text(L10n.text("The photo may include people or private details nearby. Turn off photo checks if you do not want to send it."))
            }
            Section(L10n.text("Where it goes and for how long")) {
                Text(L10n.text("Deep checks run on Safe QR servers in AWS Frankfurt, in the EU. Photos are analysed in memory and never stored. Check records expire after 24 hours."))
                Text(L10n.text("The isolated browser visits the website on the server. It does not sign in, pay or use your iPhone’s cookies. Safe QR does not log raw codes or photos in the app."))
            }
            Section(L10n.text("AI and the limits of a check")) {
                Text(L10n.text("AI combines website, surroundings and known-scam evidence. It can miss a scam or wrongly flag an honest code. The result explains its reasons and what could not be checked."))
                Text(L10n.text("AI cannot lower the score below a danger proven by the on-device rules. You always make the final decision before anything opens or is handed to another app."))
            }
            Section(L10n.text("Your choices")) {
                Text(L10n.text("Turn off deep checks or photo checks at any time. Offline checks keep working. Turning a setting off stops future uploads; it cannot recall information already sent."))
            }
        }
        .navigationTitle(L10n.text("Privacy & AI"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

