import SwiftUI
import SafeQRKit

struct ConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    let action: CodeAction
    let level: RiskLevel
    var reason: String? = nil
    let onConfirm: () -> Void
    @State private var height: CGFloat = 480

    private var risky: Bool { level != .safe || action.requiredConfirmation.isRisky }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if level == .danger {
                    Image(systemName: "exclamationmark.octagon.fill").font(.system(size: 38))
                        .foregroundStyle(RiskLevel.danger.color).accessibilityHidden(true)
                }
                Text(level == .danger ? L10n.text("Really continue?") : action.requiredConfirmation.title)
                    .font(.system(.title, design: .rounded, weight: .bold)).accessibilityAddTraits(.isHeader)
                destination
                Text(action.requiredConfirmation.message).fixedSize(horizontal: false, vertical: true)
                if let reason, risky {
                    Text(reason).font(.subheadline.weight(.medium)).foregroundStyle(level.color)
                }
                if !typeSize.isAccessibilitySize { decisionButtons }
            }
            .padding(24).padding(.top, 10)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 12 }
        }
        .safeAreaInset(edge: .bottom) {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) { decisionButtons }.padding(20).background(.bar)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(height), .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var decisionButtons: some View {
        if risky {
            backButton
            if level == .danger {
                HoldToContinueButton { dismiss(); onConfirm() }
            } else {
                Button(L10n.text("Continue anyway"), role: .destructive) { dismiss(); onConfirm() }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .accessibilityIdentifier("confirm-action")
            }
        } else {
            Button { dismiss(); onConfirm() } label: {
                Text(action.requiredConfirmation.confirmTitle).frame(maxWidth: .infinity, minHeight: 36)
            }.buttonStyle(.glassProminent).foregroundStyle(AppStyle.onAccent)
                .accessibilityIdentifier("confirm-action")
            Button(L10n.text("Go back"), role: .cancel) { dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var backButton: some View {
        Button(role: .cancel) { dismiss() } label: {
            Text(L10n.text("Go back")).fontWeight(.semibold).frame(maxWidth: .infinity, minHeight: 36)
        }.buttonStyle(.glassProminent).foregroundStyle(AppStyle.onAccent)
            .accessibilityIdentifier("confirm-go-back")
    }

    @ViewBuilder private var destination: some View {
        switch action.kind {
        case .open(let url): AddressCapsule(url: url)
        case .call(let number), .sendSMS(let number, _):
            Text(number).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: Capsule())
        case .composeEmail(let recipient, _, _): Text(recipient).fontWeight(.semibold)
        case .joinWiFi(let ssid, _, _): Label(ssid, systemImage: "wifi").font(.headline)
        default: EmptyView()
        }
    }
}

struct ConfirmedActionButton: View {
    let action: CodeAction
    var symbol: String? = nil
    var level: RiskLevel = .safe
    @State private var confirming = false
    @State private var handler = ActionHandler()

    var body: some View {
        Button { confirming = true } label: {
            if let symbol { Label(action.title, systemImage: symbol) }
            else { Text(action.title) }
        }
            .sheet(isPresented: $confirming) {
                ConfirmationSheet(action: action, level: level) {
                    Task { await handler.perform(action) }
                }
            }
            .alert(L10n.text("Safe QR"), isPresented: Binding(get: { handler.message != nil }, set: { if !$0 { handler.message = nil } })) {
                Button(L10n.text("OK"), role: .cancel) { handler.message = nil }
            } message: { Text(handler.message ?? "") }
    }
}

func sourceAction(title: String, url: URL) -> CodeAction {
    CodeAction(id: url.absoluteString, kind: .open(url), title: title,
               confirmation: Confirmation(title: L10n.text("Open this source?"),
                                          message: L10n.format("Your browser will open %@.", url.host() ?? url.absoluteString),
                                          confirmTitle: L10n.text("Open website"), isRisky: false))
}
