import SwiftUI

struct SandboxScreenshot: View {
    let url: URL
    @State private var image: UIImage?
    @State private var failed = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image {
                Button { expanded = true } label: {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 180).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right").padding(10).glassEffect(in: Circle()).padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Enlarge the isolated browser preview"))
            } else if failed {
                Text(L10n.text("The website preview could not be loaded.")).font(.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView(L10n.text("Loading website preview…"))
            }
        }
        .fullScreenCover(isPresented: $expanded) {
            NavigationStack {
                ScrollView([.horizontal, .vertical]) {
                    if let image { Image(uiImage: image).resizable().scaledToFit().containerRelativeFrame(.horizontal) }
                }
                .navigationTitle(L10n.text("Website preview"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(role: .close) { expanded = false } } }
            }
        }
        .task(id: url) {
            guard url.scheme == "https", let host = url.host(),
                  host == "api.bezpecneqr.cz" || host.hasSuffix(".amazonaws.com") else { failed = true; return }
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10
            configuration.httpCookieStorage = nil
            configuration.urlCache = nil
            configuration.urlCredentialStorage = nil
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
