import SwiftUI

struct CloudEvidenceView: View {
    let verdict: CloudVerdict
    let photo: ScenePhoto?

    var body: some View {
        if let scene = verdict.scene {
            DetailSection(title: L10n.text("Around the code")) {
                if let photo, let image = UIImage(data: photo.jpeg) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel(L10n.text("The surroundings captured with this code"))
                }
                Text(scene.summary)
                ForEach(Array((scene.tamperingSigns ?? []).enumerated()), id: \.offset) { _, sign in
                    Label(sign, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
                }
            }.id("scene")
        }
        if let cases = verdict.intel, !cases.isEmpty {
            DetailSection(title: L10n.text("Similar reported scams")) {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title).font(.headline)
                        Text(item.summary).foregroundStyle(.secondary)
                        Text("\(item.sourceUrl.host() ?? "") · \(item.publishedAt)").font(.caption).foregroundStyle(.secondary)
                        ConfirmedActionButton(action: sourceAction(title: L10n.text("Read the source"), url: item.sourceUrl))
                    }
                }
            }
        }
    }
}
