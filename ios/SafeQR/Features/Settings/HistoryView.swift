import SwiftUI
import SafeQRKit

struct HistoryView: View {
    @Environment(\.appTheme) private var theme

    @Environment(AppServices.self) private var services
    @State private var clearing = false

    var body: some View {
        Group {
            if let history = services.history, !history.records.isEmpty {
                List {
                    Section {
                        Text(L10n.text("Saved results describe the time of the scan. They are not a fresh safety check."))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(history.records) { record in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: CodeKind(rawValue: record.kind)?.symbol ?? "qrcode")
                                .font(.title2).foregroundStyle(theme.accent).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(record.title).font(.headline)
                                Label(RiskLevel(score: record.score).title, systemImage: RiskLevel(score: record.score).symbol)
                                    .foregroundStyle(RiskLevel(score: record.score).color)
                                Text(record.date, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text(record.score.formatted()).font(.headline.monospacedDigit())
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .swipeActions {
                            Button(L10n.text("Delete"), role: .destructive) { history.delete(record) }
                        }
                        .contextMenu { Button(L10n.text("Delete"), role: .destructive) { history.delete(record) } }
                    }
                }
            } else {
                ContentUnavailableView(L10n.text("No saved scans"), systemImage: "clock",
                                       description: Text(L10n.text("Turn on scan history in Settings to keep a private record on this iPhone.")))
            }
        }
        .navigationTitle(L10n.text("Scan history"))
        .toolbar {
            if services.history?.records.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("Clear all"), role: .destructive) { clearing = true }
                }
            }
        }
        .confirmationDialog(L10n.text("Delete all saved scans?"), isPresented: $clearing, titleVisibility: .visible) {
            Button(L10n.text("Delete all scans"), role: .destructive) { services.history?.clear() }
            Button(L10n.text("Cancel"), role: .cancel) { }
        } message: { Text(L10n.text("This removes the history from this iPhone. You cannot undo it.")) }
        .alert(L10n.text("History"), isPresented: Binding(get: { services.history?.errorMessage != nil }, set: { if !$0 { services.history?.errorMessage = nil } })) {
            Button(L10n.text("OK"), role: .cancel) { services.history?.errorMessage = nil }
        } message: { Text(services.history?.errorMessage ?? "") }
    }
}
