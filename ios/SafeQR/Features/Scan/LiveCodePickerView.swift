import SwiftUI

struct LiveCodeSelection: Identifiable {
    let id = UUID()
    let codes: [TrackedCode]
    let privateScene: Bool
}

struct LiveCodePickerView: View {
    let selection: LiveCodeSelection
    let onSelect: (TrackedCode) -> Void
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.text("Choose a code to check")).font(.title3.weight(.medium))
                    if ScanPresentationGate.mayBeOverlaid(selection.codes) {
                        Text(L10n.text("A sticker may be covering the original."))
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(Array(selection.codes.enumerated()), id: \.element.id) { index, code in
                        Button { onSelect(code) } label: {
                            CodeChoiceRow(number: index + 1, analysis: code.analysis,
                                          model: services.checks.models[code.analysis.raw])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(L10n.text("More than one code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(role: .close) { dismiss() } }
            }
        }
    }
}
