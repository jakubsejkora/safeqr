import SwiftUI
import SafeQRKit

struct ResultActionBar: View {
    @Environment(\.appTheme) private var theme

    let actions: [CodeAction]
    let level: RiskLevel
    var compact = false
    var pending = false
    let goBack: () -> Void
    let perform: (CodeAction) -> Void

    private var primary: CodeAction? { actions.first(where: \.isPrimary) ?? actions.first }
    private var risky: Bool { level != .safe || primary?.isRisky == true }

    var body: some View {
        VStack(spacing: 6) {
            if risky || pending {
                Button(action: goBack) {
                    Text(L10n.text("Back to scanning")).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
                if let primary {
                    Button { perform(primary) } label: {
                        Text(pending ? primary.title : primary.isHandoff ? L10n.text("Continue anyway…") : primary.title)
                            .frame(minHeight: 38)
                    }.tint(primary.isHandoff ? level.color : theme.accent)
                    .disabled(pending && primary.isHandoff)
                }
            } else if let primary {
                Button { perform(primary) } label: {
                    Text(primary.title).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glassProminent).foregroundStyle(theme.onAccent)
            }
            if actions.count > 1 && !compact {
                HStack(spacing: 24) {
                    ForEach(actions.filter { $0.id != primary?.id }) { action in
                        Button(action.title) { perform(action) }.font(.subheadline).frame(minHeight: 32)
                            .disabled(pending && action.isHandoff)
                    }
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
