import SwiftUI
import SafeQRKit

struct CodePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let scan: ImportedScan
    let onSelect: (ScannedCode) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.format("This picture contains %lld codes. A sticker may be covering the original.", scan.codes.count))
                        .font(.title3.weight(.medium))
                    if let image = UIImage(data: scan.jpeg) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .accessibilityLabel(L10n.text("The imported picture"))
                    }
                }
                Section(L10n.text("Choose a code to check")) {
                    ForEach(Array(scan.codes.enumerated()), id: \.element.id) { index, code in
                        let content = CodeInspector(locale: L10n.locale).inspect(code.raw, symbology: code.symbology).content
                        Button {
                            dismiss()
                            onSelect(code)
                        } label: {
                            HStack(alignment: .top, spacing: 16) {
                                Text("\(index + 1)").font(.title3.bold()).foregroundStyle(AppStyle.accent)
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(content.title, systemImage: content.kind.symbol).font(.headline)
                                    Text(content.summary).foregroundStyle(.secondary).lineLimit(4)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(L10n.text("More than one code"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.text("Cancel")) { dismiss() } } }
        }
    }
}
