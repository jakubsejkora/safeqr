import SwiftUI

struct AboutView: View {
    private let websiteURL = URL(string: "https://safeqr.cz")
    private let repositoryURL = URL(string: "https://github.com/jakubsejkora/safeqr")
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ShieldMark(size: 92)
                    Text("Safe QR").font(.title.bold())
                    Text(L10n.text("Know what a QR code does before you act on it.")).multilineTextAlignment(.center)
                    Text(L10n.format("Version %@", version)).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            Section {
                if let websiteURL {
                    ConfirmedActionButton(action: sourceAction(title: "safeqr.cz", url: websiteURL))
                }
                if let repositoryURL {
                    ConfirmedActionButton(action: sourceAction(title: "GitHub", url: repositoryURL))
                }
                NavigationLink(L10n.text("Open-source notices")) {
                    List {
                        Text(L10n.text("Safe QR uses Apple system frameworks and the local SafeQRKit package. No third-party libraries are bundled in the app target."))
                        if let repositoryURL {
                            ConfirmedActionButton(action: sourceAction(title: L10n.text("Source code and licences"), url: repositoryURL))
                        }
                    }
                    .navigationTitle(L10n.text("Open-source notices"))
                }
            }
            Section {
                Text(L10n.text("Built at The FinTechers Hackathon 2026 in Prague."))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.text("About Safe QR"))
    }
}
