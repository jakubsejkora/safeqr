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
        case multiple = "scannerMultiple"
    }

    private(set) var isFrozen = false
    let mode: Mode
    let state = CameraState.ready
    let hasUltraWide = true
    let hasTorch = true
    let sceneContainsPrivateCodes = false
    let unavailableMessage = ""
    let availableZooms = CameraZoom.allCases
    private(set) var zoom: CameraZoom = .main
    private(set) var torchEnabled = false
    private(set) var codes: [TrackedCode]
    let frame = ScannerFixture.image

    init(mode: Mode) {
        self.mode = mode
        codes = mode == .idle ? [] : mode == .multiple ? Self.multipleCodes : Self.lockedCodes
    }

    var preview: AnyView {
        AnyView(GeometryReader { geometry in
            if let frame = self.frame {
                Image(uiImage: frame).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(self.zoom.mainFactor).clipped()
            }
        })
    }

    func start(requestPermission: Bool) async { isFrozen = false }
    func freeze() async { isFrozen = true; torchEnabled = false }
    func stop() { torchEnabled = false }
    func toggleTorch() { torchEnabled.toggle() }

    func selectZoom(_ zoom: CameraZoom) {
        self.zoom = zoom
        codes = mode == .idle ? [] : Self.lockedCodes.map { code in
            var result = code
            let factor = Double(zoom.mainFactor)
            let original = code.bounds
            let bounds = CodeBounds(rect: CGRect(x: 0.5 + (original.x - 0.5) * factor,
                                                y: 0.5 + (original.y - 0.5) * factor,
                                                width: original.width * factor, height: original.height * factor))
            result.bounds = bounds
            result.observation = CameraObservation(code: ScannedCode(raw: code.observation.code.raw,
                symbology: code.observation.code.symbology, bounds: bounds), scene: code.observation.scene,
                frameSize: code.observation.frameSize, ultraBounds: original, ultraSize: code.observation.ultraSize)
            return result
        }
    }

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
    static var multipleCodes: [TrackedCode] {
        let first = lockedCodes
        let bounds = CodeBounds(rect: CGRect(x: 0.62, y: 0.37, width: 0.06, height: 0.22))
        let code = ScannedCode(raw: "https://parking.praha.eu", symbology: .qr, bounds: bounds)
        return first + [TrackedCode(observation: CameraObservation(code: code, scene: scene,
            frameSize: CGSize(width: 1280, height: 960), ultraBounds: bounds, ultraSize: CGSize(width: 1280, height: 960)))]
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
        ScannerOverlay(codes: ScannerFixture.lockedCodes)
    }.ignoresSafeArea()
}

#Preview("Scanner · idle") {
    Color.gray.overlay { ScannerOverlay(codes: []) }.ignoresSafeArea()
}
#endif
