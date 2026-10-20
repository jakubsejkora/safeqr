import SwiftUI
import SafeQRKit

struct EventPayloadView: View {
    @Environment(\.appTheme) private var theme

    let facts: [Fact]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = facts.first(where: { $0.id == "name" })?.value { Text(title).font(.title2.weight(.semibold)) }
            ForEach(facts.filter { $0.id != "name" }) { FactRow(fact: $0) }
        }
        .padding(.leading, 18)
        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 4) }
    }
}
