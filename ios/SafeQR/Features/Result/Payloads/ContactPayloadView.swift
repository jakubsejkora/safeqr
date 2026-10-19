import SwiftUI
import SafeQRKit

struct ContactPayloadView: View {
    let facts: [Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Text(initials).font(.system(.title2, design: .rounded, weight: .medium))
                    .frame(width: 68, height: 68).background(.quaternary, in: Circle()).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.title2.weight(.semibold))
                    if let organization = facts.first(where: { $0.id == "organization" })?.value { Text(organization).foregroundStyle(.secondary) }
                }
            }
            ForEach(facts.filter { !["name", "organization"].contains($0.id) }) { FactRow(fact: $0) }
        }
    }

    private var name: String { facts.first { $0.id == "name" }?.value ?? L10n.text("Contact") }

    private var initials: String {
        name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
