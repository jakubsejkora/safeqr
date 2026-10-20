import SwiftUI

enum CameraState { case idle, ready, denied, unavailable }

@MainActor
protocol CameraSource: AnyObject {
    var state: CameraState { get }
    var isFrozen: Bool { get }
    var preview: AnyView { get }
    var hasUltraWide: Bool { get }
    var hasTorch: Bool { get }
    var availableZooms: [CameraZoom] { get }
    var zoom: CameraZoom { get }
    var torchEnabled: Bool { get }
    var codes: [TrackedCode] { get }
    var sceneContainsPrivateCodes: Bool { get }
    var unavailableMessage: String { get }

    func start(requestPermission: Bool) async
    func stop()
    func freeze() async
    func toggleTorch()
    func selectZoom(_ zoom: CameraZoom)
}

extension CameraSource {
    var showsUltraWide: Bool { zoom == .ultraWide }
    func start() async { await start(requestPermission: false) }
}
