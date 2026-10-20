#if DEBUG
import SwiftUI
import Observation

@MainActor @Observable
final class ScannerFixture: CameraSource {
    enum Mode: String, CaseIterable {
        case idle = "scannerIdle"
        case locked = "scannerLocked"
        case checking = "scannerChecking"
        case danger = "scannerDanger"
    }

    let mode: Mode
    let state = CameraState.ready
    let hasUltraWide = true
    let hasTorch = true
    let sceneContainsPrivateCodes = false
    let unavailableMessage = ""
    var showsUltraWide = false
    private(set) var torchEnabled = false
    let codes: [TrackedCode]
    let thumbnail = ScannerFixture.image

    init(mode: Mode) {
        self.mode = mode
        codes = mode == .idle ? [] : Self.lockedCodes
    }

    var preview: AnyView {
        AnyView(GeometryReader { geometry in
            if let thumbnail = self.thumbnail {
                Image(uiImage: thumbnail).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
        })
    }

    func start(requestPermission: Bool) async {}
    func stop() { torchEnabled = false }
    func toggleTorch() { torchEnabled.toggle() }

    static var image: UIImage? {
        guard let url = Bundle.main.url(forResource: "parking-machine", withExtension: "jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    static var scene: ScenePhoto? {
        guard let jpeg = image?.jpegData(compressionQuality: 0.7) else { return nil }
        return ScenePhoto(jpeg: jpeg, source: .photo,
                          bounds: CodeBounds(rect: CGRect(x: 0.418, y: 0.352, width: 0.205, height: 0.275)))
    }
    static var lockedCodes: [TrackedCode] {
        let bounds = CodeBounds(rect: CGRect(x: 0.418, y: 0.352, width: 0.205, height: 0.275))
        let code = ScannedCode(raw: DebugSample.training.raw, symbology: .qr, bounds: bounds)
        return [TrackedCode(observation: CameraObservation(code: code, scene: scene, frameSize: CGSize(width: 1280, height: 960),
                                                           ultraBounds: bounds, ultraSize: CGSize(width: 1280, height: 960)))]
    }
}
#Preview("Scanner · locked") {
    GeometryReader { geometry in
        if let image = ScannerFixture.image {
            Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        ScannerOverlay(codes: ScannerFixture.lockedCodes) { _ in }
    }.ignoresSafeArea()
}

#Preview("Scanner · idle") {
    Color.gray.overlay { ScannerOverlay(codes: []) { _ in } }.ignoresSafeArea()
}
#endif
