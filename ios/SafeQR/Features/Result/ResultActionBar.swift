import SwiftUI
import SafeQRKit

struct ResultActionBar: View {
    let actions: [CodeAction]
    let level: RiskLevel
    var compact = false
    var pending = false
    let goBack: () -> Void
    let perform: (CodeAction) -> Void
    @Environment(\.appTheme) private var theme

    private var handoffs: [CodeAction] { actions.filter(\.isHandoff) }
    private var primary: CodeAction? { handoffs.first(where: \.isPrimary) ?? handoffs.first }
    private var risky: Bool { level != .safe || primary?.isRisky == true }
    private var bankPayment: Bool {
        if let primary, case .sharePayment = primary.kind { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 6) {
            if risky || pending || primary == nil {
                Button(action: goBack) {
                    Text(L10n.text("Back to scanning")).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
                if let primary {
                    Button { perform(primary) } label: {
                        Text(pending || bankPayment ? primary.title : primary.isHandoff ? L10n.text("Continue anyway…") : primary.title)
                            .frame(minHeight: 38)
                    }.tint(primary.isHandoff ? level.color : theme.accent)
                    .disabled(pending && primary.isHandoff)
                }
            } else if let primary {
                Button { perform(primary) } label: {
                    Text(primary.title).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
            }
            if handoffs.count > 1 && !compact {
                HStack(spacing: 24) {
                    ForEach(handoffs.filter { $0.id != primary?.id }) { action in
                        Button(action.title) { perform(action) }.font(.subheadline).frame(minHeight: 32)
                            .disabled(pending && action.isHandoff)
                    }
                }
            }
            if bankPayment {
                Text(L10n.text("Choose your bank. Not listed? Save the image, then in your bank choose Payment → QR code → From photos."))
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
