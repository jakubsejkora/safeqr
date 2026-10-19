import SwiftUI

struct LinkJourneyView: View {
    let link: LinkReport
    let original: String

    var body: some View {
        DetailSection(title: L10n.text("Where the link leads")) {
            VStack(alignment: .leading, spacing: 0) {
                stop(title: L10n.text("QR code"), address: original, symbol: "qrcode", last: false)
                ForEach(Array(link.hops.enumerated()), id: \.offset) { _, hop in
                    stop(title: movement(hop.via), address: hop.url, symbol: "arrow.down", last: false)
                }
                stop(title: link.pageTitle ?? L10n.text("Final destination"), address: link.finalUrl, symbol: "globe", last: true)
            }
            if let asksFor = link.asksFor, !asksFor.isEmpty {
                ForEach(asksFor, id: \.self) { item in
                    Text(requestLabel(item)).font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.quaternary, in: Capsule())
                }
            }
            if let days = link.domainAgeDays {
                Text(L10n.format("Domain registered %lld days ago", days)).font(.footnote).foregroundStyle(.secondary)
            }
            if let url = link.screenshotUrl { SandboxScreenshot(url: url).id("sandbox") }
            Text(L10n.text("Opened in an isolated browser in AWS Frankfurt — away from your iPhone."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func stop(title: String, address: String, symbol: String, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.subheadline).frame(width: 24, height: 24).accessibilityHidden(true)
                if !last { Rectangle().fill(.separator).frame(width: 1).frame(minHeight: 36) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                if let url = URL(string: address) {
                    Text(url.host() ?? address).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                    if !url.path.isEmpty && url.path != "/" {
                        Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                } else { Text(address).font(.callout).foregroundStyle(.secondary) }
            }.padding(.bottom, last ? 0 : 22)
            Spacer(minLength: 0)
        }.fixedSize(horizontal: false, vertical: true)
    }

    private func movement(_ via: String) -> String {
        switch via {
        case "http": L10n.text("Redirect")
        case "meta": L10n.text("Page refresh")
        case "javascript": L10n.text("JavaScript redirect")
        default: L10n.text("Another page")
        }
    }

    private func requestLabel(_ value: String) -> String {
        let keys = ["password": "Asks for a password", "card": "Asks for card details", "bankLogin": "Asks for bank login",
                    "phone": "Asks for a phone number", "otp": "Asks for a one-time code", "personalData": "Asks for personal details",
                    "payment": "Asks for a payment", "appInstall": "Asks to install an app", "permission": "Asks for permission"]
        return L10n.text(keys[value] ?? "Asks for more information")
    }
}
