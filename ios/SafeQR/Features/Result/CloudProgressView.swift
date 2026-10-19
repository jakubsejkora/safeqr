import SwiftUI

struct CloudProgressView: View {
    let steps: [CheckStep]
    let checking: Bool
    let elapsedSeconds: Int
    let completed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if checking {
            VStack(alignment: .leading, spacing: 10) {
                if steps.isEmpty { ProgressView(L10n.text("Starting the deep check…")) }
                checklist
            }
            .font(.subheadline)
            .accessibilityElement(children: .contain)
        } else {
            DisclosureGroup {
                checklist.padding(.top, 8)
            } label: {
                Label(completed ? L10n.format("Deep check · %lld s", elapsedSeconds) : L10n.text("Deep check unavailable"),
                      systemImage: completed ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.tint(.secondary)
        }
    }

    private var checklist: some View {
        ForEach(steps) { step in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: symbol(step.status))
                    .symbolEffect(.variableColor.iterative, isActive: step.status.value == .running && !reduceMotion)
                    .frame(width: 20).foregroundStyle(step.status.value == .running ? AppStyle.accent : .secondary)
                Text(label(step)).foregroundStyle(step.status.value == .pending ? .secondary : .primary)
                Spacer(minLength: 0)
                if step.status.value == .skipped || step.status.value == .failed || step.status.value == nil {
                    Text(step.status.value == .skipped ? L10n.text("Skipped") : L10n.text("Unavailable"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(statusLabel(step.status))
        }
    }

    private func label(_ step: CheckStep) -> String {
        let labels = ["redirects": "Following redirects", "sandbox": "Opening the page in an isolated browser",
                      "intel": "Comparing with reported scams", "scene": "Looking around the code", "verdict": "Putting the verdict together"]
        return labels[step.id].map(L10n.text) ?? step.label
    }

    private func statusLabel(_ status: CloudEnum<CheckStep.Status>) -> String {
        switch status.value {
        case .pending: L10n.text("Waiting")
        case .running: L10n.text("In progress")
        case .done: L10n.text("Done")
        case .skipped: L10n.text("Skipped")
        case .failed: L10n.text("Unavailable")
        case nil: L10n.text("Unknown status")
        }
    }

    private func symbol(_ status: CloudEnum<CheckStep.Status>) -> String {
        switch status.value {
        case .done: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle"
        case .skipped: "minus.circle"
        case .pending: "circle"
        case .running: "ellipsis.circle"
        case nil: "questionmark.circle"
        }
    }
}
