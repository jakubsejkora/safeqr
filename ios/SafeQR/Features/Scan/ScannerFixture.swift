#if DEBUG
import SwiftUI

@MainActor enum ScannerFixture {
    static var enabled: Bool { ["scannerIdle", "scannerLocked"].contains(DebugLaunch.screen ?? "") }
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
    static var codes: [TrackedCode] {
        DebugLaunch.screen == "scannerLocked" ? lockedCodes : []
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
