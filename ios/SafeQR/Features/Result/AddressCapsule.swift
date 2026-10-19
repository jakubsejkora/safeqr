import SwiftUI
import SafeQRKit

struct AddressCapsule: View {
    let url: URL

    var body: some View {
        let parts = AddressParts(url: url)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: parts.unencrypted ? "lock.slash" : "globe")
                .foregroundStyle(parts.unencrypted ? RiskLevel.danger.color : .secondary)
                .accessibilityLabel(parts.unencrypted ? L10n.text("Unencrypted connection") : L10n.text("Website address"))
            address(parts).textSelection(.enabled)
                .font(.callout).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
    }

    private func address(_ parts: AddressParts) -> Text {
        var text = segment(parts.prefix, primary: false, suspicious: parts.suspiciousLabels)
        text.append(segment(parts.domain, primary: true, suspicious: parts.suspiciousLabels))
        var suffix = AttributedString(parts.suffix)
        suffix.foregroundColor = .secondary
        text.append(suffix)
        return Text(text)
    }

    private func segment(_ value: String, primary: Bool, suspicious: Set<String>) -> AttributedString {
        var result = AttributedString()
        for (index, label) in value.components(separatedBy: ".").enumerated() {
            if index > 0 { result.append(AttributedString(".")) }
            var part = AttributedString(label)
            part.foregroundColor = suspicious.contains(label) ? RiskLevel.danger.color : primary ? .primary : .secondary
            if primary { part.font = .body.weight(.semibold) }
            if suspicious.contains(label) { part.underlineStyle = .single }
            result.append(part)
        }
        return result
    }
}
