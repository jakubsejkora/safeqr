import SwiftUI
import SafeQRKit

struct ResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var model: ResultModel
    @State private var selectedAction: CodeAction?
    @State private var handler = ActionHandler()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    verdictHeader
                    SectionCard(title: L10n.text("What's inside"), symbol: model.analysis.content.kind.symbol) {
                        Text(model.analysis.content.title).font(.title3.weight(.semibold))
                        ForEach(model.analysis.content.facts) { fact in
                            FactRow(fact: fact)
                        }
                    }
                    if model.checking || !model.steps.isEmpty {
                        CloudProgressView(steps: model.steps, checking: model.checking)
                    }
                    SectionCard(title: L10n.text("Why"), symbol: "text.bubble") {
                        if model.assessment.findings.isEmpty {
                            Text(L10n.text("No warning signs were found in the code itself. This does not prove it is safe."))
                        }
                        ForEach(model.assessment.findings) { finding in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(finding.title, systemImage: finding.severity == .info ? "info.circle" : "exclamationmark.triangle")
                                    .font(.body.weight(.semibold))
                                Text(finding.detail).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    SectionCard(title: L10n.text("If you continue"), symbol: "arrow.up.forward.app") {
                        if model.assessment.consequences.isEmpty {
                            Text(L10n.text("Nothing happens until you choose an action and confirm it."))
                        }
                        ForEach(Array(model.assessment.consequences.enumerated()), id: \.offset) { _, item in
                            Label(item, systemImage: "arrow.right").fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let verdict = model.verdict { CloudEvidenceView(verdict: verdict) }
                    SectionCard(title: L10n.text("What we couldn't check"), symbol: "eye.slash") {
                        ForEach(Array(model.limitations.enumerated()), id: \.offset) { _, item in Text(item) }
                        Text(L10n.text("A low score is not a guarantee. Check who you are paying or sharing information with."))
                            .foregroundStyle(.secondary)
                    }
                    actions
                    Text(L10n.text("You stay in control."))
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 16)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(AppStyle.canvas)
            .navigationTitle(L10n.text("Your result"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Done")) { dismiss() }.accessibilityIdentifier("result-done")
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: model.assessment.score)
        .sheet(item: $selectedAction) { action in
            ConfirmationSheet(action: action, level: model.assessment.level) {
                Task { await handler.perform(action, payload: model.analysis.content.payload) }
            }
        }
        .sheet(item: $handler.presentation) { ActionPresentationView(presentation: $0) }
        .alert(L10n.text("Safe QR"), isPresented: Binding(get: { handler.message != nil }, set: { if !$0 { handler.message = nil } })) {
            Button(L10n.text("OK"), role: .cancel) { handler.message = nil }
        } message: { Text(handler.message ?? "") }
        .task(id: services.preferences.consent) {
            await model.run(using: services.checker, consent: services.preferences.consent)
            services.history?.record(model.analysis, assessment: model.assessment, enabled: services.preferences.historyEnabled)
        }
    }

    private var verdictHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.assessment.level.title, systemImage: model.assessment.level.symbol)
                        .font(.title.bold())
                        .foregroundStyle(model.assessment.level.color)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.verdict == nil ? L10n.text("Checked on this iPhone") : L10n.text("Device + deep check"))
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ScoreRing(assessment: model.assessment)
            }
            Text(model.headline)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.assessment.level.color.opacity(0.09), in: RoundedRectangle(cornerRadius: 28))
        .accessibilityIdentifier("verdict-header")
    }

    private var actions: some View {
        VStack(spacing: 12) {
            ForEach(model.analysis.actions) { action in
                if action.isPrimary {
                    actionButton(action).buttonStyle(.glassProminent)
                        .foregroundStyle(AppStyle.onAccent)
                        .tint(action.isHandoff && model.assessment.level != .safe ? model.assessment.level.color : AppStyle.accent)
                } else {
                    actionButton(action).buttonStyle(.glass)
                }
            }
        }
        .padding(.top, 8)
    }

    private func actionButton(_ action: CodeAction) -> some View {
        Button(role: action.isHandoff && (model.assessment.level != .safe || action.requiredConfirmation.isRisky) ? .destructive : nil) {
            if action.isHandoff { selectedAction = action }
            else { Task { await handler.perform(action, payload: model.analysis.content.payload) } }
        } label: {
            Text(action.title).font(.headline).frame(maxWidth: .infinity, minHeight: 36)
        }
    }
}

private struct ScoreRing: View {
    let assessment: RiskAssessment
    @ScaledMetric(relativeTo: .title) private var diameter = 86
    var body: some View {
        ZStack {
            Circle().stroke(assessment.level.color.opacity(0.14), lineWidth: 6)
            Circle().trim(from: 0, to: max(0.02, Double(assessment.score) / 100))
                .stroke(assessment.level.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(assessment.score.formatted()).font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                Text("/ 100").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("Risk score: %lld out of 100", assessment.score))
    }
}
