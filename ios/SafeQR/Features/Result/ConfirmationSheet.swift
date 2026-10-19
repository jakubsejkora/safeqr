import SwiftUI
import SafeQRKit

struct ConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let action: CodeAction
    let level: RiskLevel
    let onConfirm: () -> Void
    @State private var secondDecision = false

    private var risky: Bool { level != .safe || action.requiredConfirmation.isRisky }
    private var warningColor: Color { level == .caution ? RiskLevel.caution.color : RiskLevel.danger.color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: secondDecision ? "hand.raised.fill" : "arrow.up.forward.app")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(risky ? warningColor : AppStyle.accent)
                        .accessibilityHidden(true)
                    Text(secondDecision ? L10n.text("This code may harm you") : action.requiredConfirmation.title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(secondDecision ? L10n.text("We recommend going back. Continue only if you understand the risk and trust the destination.") : action.requiredConfirmation.message)
                        .font(.title3)
                    if risky {
                        Button(role: .cancel) { dismiss() } label: {
                            Text(L10n.text("Go back"))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(AppStyle.onAccent)
                        .tint(AppStyle.accent)
                        .accessibilityIdentifier("confirm-go-back")
                        continueButton
                            .buttonStyle(.glass)
                            .tint(warningColor)
                    } else {
                        continueButton
                            .buttonStyle(.glassProminent)
                            .foregroundStyle(AppStyle.onAccent)
                            .tint(AppStyle.accent)
                        Button(L10n.text("Go back"), role: .cancel) { dismiss() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.glass)
                    }
                }
                .padding(24)
            }
            .navigationTitle(L10n.text("Your decision"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Cancel")) { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private var continueButton: some View {
        Button(role: risky ? .destructive : nil) {
            if level == .danger && !secondDecision {
                secondDecision = true
            } else {
                dismiss()
                onConfirm()
            }
        } label: {
            Text(risky ? L10n.text("Continue anyway") : action.requiredConfirmation.confirmTitle)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .accessibilityIdentifier(secondDecision ? "confirm-danger" : "confirm-action")
    }
}

struct ConfirmedActionButton: View {
    let action: CodeAction
    var level: RiskLevel = .safe
    @State private var confirming = false
    @State private var handler = ActionHandler()

    var body: some View {
        Button(action.title) { confirming = true }
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
