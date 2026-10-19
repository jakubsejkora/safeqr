import SwiftUI
import SafeQRKit

struct SecretPayloadView: View {
    let content: CodeContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "key.slash").font(.title).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Private code")).font(.title3.weight(.semibold))
                    Text(L10n.text("Keep this code to yourself. It can give someone access to your account or SIM."))
                        .foregroundStyle(.secondary)
                }
            }
            Text(L10n.text("Contents hidden · stays on this iPhone"))
                .font(.subheadline.weight(.medium)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            ForEach(content.facts.filter { $0.id != "secret" }) { FactRow(fact: $0) }
        }
    }
}
