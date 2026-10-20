import SwiftUI
import SafeQRKit

struct CodePickerView: View {
    @Environment(\.appTheme) private var theme
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
                            .overlay {
                                GeometryReader { geometry in
                                    ForEach(Array(scan.codes.enumerated()), id: \.element.id) { index, code in
                                        let bounds = code.bounds
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(theme.accent, lineWidth: 2)
                                            .overlay(alignment: .topLeading) {
                                                Text("\(index + 1)").font(.caption.bold())
                                                    .padding(5).background(.background, in: Circle())
                                                    .foregroundStyle(theme.accent)
                                            }
                                            .frame(width: bounds.width * geometry.size.width,
                                                   height: bounds.height * geometry.size.height)
                                            .position(x: (bounds.x + bounds.width / 2) * geometry.size.width,
                                                      y: (bounds.y + bounds.height / 2) * geometry.size.height)
                                    }
                                }
                                .accessibilityHidden(true)
                            }
                            .frame(maxHeight: 260)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(L10n.text("The imported picture"))
                    }
                }
                Section(L10n.text("Choose a code to check")) {
                    ForEach(Array(scan.codes.enumerated()), id: \.element.id) { index, code in
                        let analysis = CodeInspector(locale: L10n.locale).inspect(code.raw, symbology: code.symbology)
                        Button {
                            dismiss()
                            onSelect(code)
                        } label: {
                            CodeChoiceRow(number: index + 1, analysis: analysis)
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
