import SwiftUI

struct CloudProgressView: View {
    let steps: [CheckStep]
    let checking: Bool

    var body: some View {
        SectionCard(title: checking ? L10n.text("Taking a closer look") : L10n.text("Deep check steps"), symbol: "sparkle.magnifyingglass") {
            if steps.isEmpty { ProgressView(L10n.text("Starting the deep check…")) }
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    if step.status.value == .running { ProgressView().accessibilityLabel(L10n.text("In progress")) }
                    else { Image(systemName: symbol(step.status)).foregroundStyle(.secondary).accessibilityHidden(true) }
                    Text(step.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text(statusLabel(step.status)).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
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
        case .pending, .running: "circle.dotted"
        case nil: "questionmark.circle"
        }
    }
}

struct CloudEvidenceView: View {
    let verdict: CloudVerdict

    var body: some View {
        if let link = verdict.link {
            SectionCard(title: L10n.text("Where the link leads"), symbol: "point.topleft.down.to.point.bottomright.curvepath") {
                ForEach(Array(link.hops.enumerated()), id: \.offset) { index, hop in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.format("Step %lld", index + 1)).font(.caption).foregroundStyle(.secondary)
                        Text(hop.url).font(.callout).textSelection(.enabled)
                    }
                }
                Text(L10n.text("Final destination")).font(.headline)
                Text(link.finalUrl).textSelection(.enabled)
                if let title = link.pageTitle { Text(title).foregroundStyle(.secondary) }
                if let url = link.screenshotUrl { SandboxScreenshot(url: url) }
            }
        }
        if let scene = verdict.scene {
            SectionCard(title: L10n.text("Around the code"), symbol: "viewfinder") {
                Text(scene.summary)
                ForEach(Array((scene.tamperingSigns ?? []).enumerated()), id: \.offset) { _, sign in
                    Label(sign, systemImage: "exclamationmark.triangle")
                }
            }
        }
        if let cases = verdict.intel, !cases.isEmpty {
            SectionCard(title: L10n.text("Similar reported scams"), symbol: "newspaper") {
                ForEach(cases) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title).font(.headline)
                        Text(item.summary)
                        Text(item.publishedAt).font(.caption).foregroundStyle(.secondary)
                        ConfirmedActionButton(action: sourceAction(title: L10n.text("Read the source"), url: item.sourceUrl))
                    }
                }
            }
        }
        if !verdict.models.isEmpty {
            DisclosureGroup(L10n.text("AI used in this check")) {
                ForEach(verdict.models, id: \.self) { Text($0).font(.footnote).textSelection(.enabled) }
            }
            .padding(20)
        }
    }
}

private struct SandboxScreenshot: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(L10n.text("A picture of the website opened by the isolated browser"))
                Text(L10n.text("Website preview. This page was opened away from your iPhone."))
                    .font(.footnote).foregroundStyle(.secondary)
            } else if failed {
                Text(L10n.text("The website preview could not be loaded.")).font(.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView(L10n.text("Loading website preview…"))
            }
        }
        .task(id: url) {
            guard url.scheme == "https", let host = url.host(),
                  host == "api.safeqr.cz" || host.hasSuffix(".amazonaws.com") else { failed = true; return }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            let session = URLSession(configuration: configuration, delegate: APIRedirectPolicy(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            do {
                let (data, response) = try await session.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200, data.count < 5_000_000,
                      let decoded = UIImage(data: data) else { failed = true; return }
                image = decoded
            } catch { failed = true }
        }
    }
}
