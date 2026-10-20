#if DEBUG
import Foundation

@MainActor
final class DebugCloudClient: CloudChecking {
    private let configuration: DebugLaunchConfiguration
    private let live: any CloudChecking

    init(configuration: DebugLaunchConfiguration, live: any CloudChecking) {
        self.configuration = configuration
        self.live = live
    }

    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        let checker: any CloudChecking = configuration.demoEnabled ? PreviewCloudClient() : live
        return try await checker.check(makeRequest, onProgress: onProgress)
    }
}
#endif
