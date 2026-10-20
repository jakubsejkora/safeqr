import SwiftUI

enum CameraState { case idle, ready, denied, unavailable }

@MainActor
protocol CameraSource: AnyObject {
    var state: CameraState { get }
    var preview: AnyView { get }
    var hasUltraWide: Bool { get }
    var hasTorch: Bool { get }
    var showsUltraWide: Bool { get set }
    var torchEnabled: Bool { get }
    var codes: [TrackedCode] { get }
    var sceneContainsPrivateCodes: Bool { get }
    var thumbnail: UIImage? { get }
    var unavailableMessage: String { get }

    func start(requestPermission: Bool) async
    func stop()
    func toggleTorch()
}

extension CameraSource {
    func start() async { await start(requestPermission: false) }
}
