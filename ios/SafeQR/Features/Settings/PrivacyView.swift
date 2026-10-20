import SwiftUI

struct PrivacyView: View {
    var body: some View {
        List {
            Section(L10n.text("On your iPhone")) {
                Text(L10n.text("Every code is checked on your iPhone first. Camera photos are kept in memory on this iPhone, not saved to your photo library."))
                Text(L10n.text("History is off by default. If enabled, only the code type, time and score are saved locally. History is excluded from backups. Delete individual entries or clear them all in Settings."))
            }
            Section(L10n.text("What a deep check sends")) {
                Text(L10n.text("With your permission, Safe QR sends the code contents, type, language, device score and warning identifiers. Photo checks also send a photo and the code’s position in it. Payment codes may include the recipient and amount."))
                Text(L10n.text("Recognized Wi-Fi, login, eSIM, contact, calendar and communication codes stay on this iPhone. A photo is not sent if we find a private code or cannot check it reliably. The app sends no GPS location."))
                Text(L10n.text("The photo may include people or private details nearby. Turn off photo checks if you do not want to send it."))
                Text(L10n.text("To check an Instagram profile, we send Apify only its public username; processing may occur outside the EU."))
            }
            Section(L10n.text("Where it goes and for how long")) {
                Text(L10n.text("Servers and storage are in AWS Frankfurt (eu-central-1). Amazon Bedrock AI may also process requests in other AWS regions within the EU."))
                Text(L10n.text("Photos are kept briefly in private encrypted storage. We delete them after the check. A one-day cleanup rule is the backup if deletion fails. Actual deletion can take longer."))
                Text(L10n.text("Check results become unavailable after 24 hours. Deleting stored data can take longer."))
                Text(L10n.text("The original code contents are removed from the record when the check finishes or is marked as failed."))
                Text(L10n.text("Website screenshots are private and encrypted. Their links last 15 minutes. A one-day cleanup rule applies; actual deletion can take longer. Keep result and screenshot links private."))
                Text(L10n.text("The isolated browser visits the website from the server. The website can see this visit and details in the link. Your iPhone’s cookies and signed-in accounts are not shared. Safe QR does not log raw codes or photos in the app."))
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

