#if DEBUG
import Foundation

struct PreviewCloudClient: CloudChecking {
    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        guard let score = await makeRequest()?.device.score else { throw CloudError.unavailable }
        let labels = ["Following redirects", "Checking the website", "Checking the surroundings", "Checking known scams", "Preparing the result"]
        let ids = ["redirects", "sandbox", "scene", "intel", "verdict"]
        for index in ids.indices {
            try await Task.sleep(for: .milliseconds(350))
            await onProgress(ids.enumerated().map { offset, id in
                CheckStep(id: id, status: .known(offset <= index ? .done : .pending), label: L10n.text(labels[offset]))
            })
        }
        return CloudVerdict(score: score, level: .known(.init(score: score)),
                            headline: L10n.text("This is a demonstration. No website was visited."), findings: [],
                            consequences: [], limitations: [L10n.text("Demo evidence is not a real safety check.")],
                            link: nil, scene: nil, intel: nil, models: ["demo"])
    }
}
#endif
