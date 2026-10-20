import SwiftUI
import SafeQRKit

struct ResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var presentation: ResultPresentation
    private var model: ResultModel { presentation.model }
    var compact = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmedAction: CodeAction?
    @State private var handler = ActionHandler()
    @State private var allReasons = false
    @State private var initialFeedback = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 14 : 26) {
                    ResultHeader(model: model, compact: compact)
                    if model.checking || !model.steps.isEmpty {
                        CloudProgressView(steps: model.steps, checking: model.checking, elapsedSeconds: model.elapsedSeconds,
                                          completed: model.verdict != nil)
                    }
                    PayloadView(content: model.analysis.content, compact: compact)
                    if let link = model.verdict?.link {
                        LinkJourneyView(link: link, original: model.analysis.raw).id("journey")
                    }
                    reasons
                    DetailSection(title: L10n.text("If you continue")) {
                        if model.assessment.consequences.isEmpty {
                            Text(L10n.text("Nothing happens until you choose an action and confirm it."))
                        }
                        ForEach(Array(model.assessment.consequences.enumerated()), id: \.offset) { _, item in
                            Text(item).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let verdict = model.verdict { CloudEvidenceView(verdict: verdict) }
                    DetailSection(title: L10n.text("What we couldn't check")) {
                        ForEach(Array(model.limitations.enumerated()), id: \.offset) { _, item in
                            Text(item).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(L10n.text("A low score is not a guarantee. Check who you are paying or sharing information with."))
                            .font(.footnote).foregroundStyle(.secondary)
                        if let models = model.verdict?.models, !models.isEmpty {
                            Text(L10n.format("AI-assisted check: %@", models.joined(separator: ", ")))
                                .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 24)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ResultActionBar(actions: model.analysis.actions, level: model.handoffLevel,
                                compact: compact || typeSize.isAccessibilitySize, pending: model.linkPending, goBack: { dismiss() }, perform: perform)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if compact || typeSize.isAccessibilitySize {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(model.analysis.actions.filter { !$0.isHandoff }) { action in
                                Button(action.title) { perform(action) }
                            }
                        } label: { Label(L10n.text("Copy or share"), systemImage: "ellipsis") }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("result-done")
                }
            }
        }
        .fontDesign(.rounded)
        .onAppear { initialFeedback = !model.linkPending }
        .sensoryFeedback(model.assessment.level.feedback, trigger: initialFeedback)
        .animation(reduceMotion ? nil : .spring(duration: 0.55), value: model.assessment.score)
        .sensoryFeedback(trigger: model.checking) { old, new in
            guard old && !new && model.verdict != nil else { return nil }
            return model.assessment.level.feedback
        }
        .sheet(item: $presentation.selectedAction, onDismiss: finishConfirmation) { action in
            ConfirmationSheet(action: action, level: model.handoffLevel, reason: model.destinationUnchecked ? L10n.text("The destination could not be checked. Be careful if you continue.") : model.assessment.findings.first?.title) {
                confirmedAction = action
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

    private var reasons: some View {
        DetailSection(title: L10n.text("Why")) {
            if model.assessment.findings.isEmpty {
                Text(L10n.text("No warning signs were found in the code itself. This does not prove it is safe."))
                    .foregroundStyle(.secondary)
            }
            ForEach(allReasons ? model.assessment.findings : Array(model.assessment.findings.prefix(3))) { finding in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: finding.severity == .danger ? "exclamationmark.octagon.fill" : finding.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(finding.severity == .danger ? RiskLevel.danger.color : finding.severity == .warning ? RiskLevel.caution.color : .secondary)
                        .frame(width: 20).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(finding.title).fontWeight(.semibold)
                        Text(finding.detail).foregroundStyle(.secondary)
                    }
                }.accessibilityElement(children: .combine)
            }
            if !allReasons, model.assessment.findings.count > 3 {
                Button(L10n.format("More reasons (%lld)", model.assessment.findings.count - 3)) { allReasons = true }
                    .frame(minHeight: 44)
            }
        }
    }

    private func finishConfirmation() {
        guard let action = confirmedAction, model.allowsHandoff else { confirmedAction = nil; return }
        confirmedAction = nil
        // Contact and calendar editors need the confirmation's presentation to finish first.
        Task { await handler.perform(action, payload: model.analysis.content.payload) }
    }

    private func perform(_ action: CodeAction) {
        if action.isHandoff {
            guard model.allowsHandoff else { return }
            presentation.selectedAction = action
        }
        else { Task { await handler.perform(action, payload: model.analysis.content.payload) } }
    }
}

