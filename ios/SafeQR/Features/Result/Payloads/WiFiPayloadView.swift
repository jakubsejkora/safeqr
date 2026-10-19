import SwiftUI
import SafeQRKit

struct WiFiPayloadView: View {
    let network: WiFiNetwork
    let facts: [Fact]
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "wifi").font(.title)
                Text(facts.first { $0.id == "networkName" }?.value ?? "").font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if network.security != .open { Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityHidden(true) }
            }
            Divider()
            ForEach(facts.filter { !["networkName", "password"].contains($0.id) }) { FactRow(fact: $0) }
            if let password = network.password {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.text("Password")).font(.subheadline).foregroundStyle(.secondary)
                        Text(revealed ? password : "••••••••").font(.system(.body, design: .monospaced))
                            .accessibilityLabel(revealed ? password : L10n.text("Password hidden"))
                    }
                    Spacer()
                    Button { revealed.toggle() } label: {
                        Label(L10n.text(revealed ? "Hide password" : "Show password"), systemImage: revealed ? "eye.slash" : "eye")
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                    }
                }
            }
        }
    }
}
