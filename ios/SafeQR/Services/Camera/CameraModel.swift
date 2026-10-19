import AVFoundation
import Observation
import SwiftUI

@MainActor @Observable
final class CameraModel {
    enum State { case idle, ready, denied, unavailable }
    private(set) var state: State = .idle
    private(set) var hasUltraWide = false
    private(set) var hasTorch = false
    var showsUltraWide = false
    private(set) var torchEnabled = false
    var onDetection: ((ScannedCode, ScenePhoto?) -> Void)?
    private(set) var capture: CameraCapture?

    func start(requestPermission: Bool = false) async {
        #if targetEnvironment(simulator)
        state = .unavailable
        #else
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined && requestPermission {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            status = AVCaptureDevice.authorizationStatus(for: .video)
        }
        guard status == .authorized else {
            state = status == .notDetermined ? .idle : .denied
            return
        }
        if capture == nil {
            capture = CameraCapture { [weak self] event in
                guard let self else { return }
                switch event {
                case .ready(let ultra, let torch):
                    hasUltraWide = ultra
                    hasTorch = torch
                    state = .ready
                case .detected(let code, let scene):
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onDetection?(code, scene)
                case .unavailable:
                    state = .unavailable
                case .torchChanged(let enabled):
                    torchEnabled = enabled
                }
            }
        }
        capture?.start()
        #endif
    }

    func stop() {
        capture?.setTorch(false)
        torchEnabled = false
        capture?.stop()
    }

    func toggleTorch() {
        torchEnabled.toggle()
        capture?.setTorch(torchEnabled)
    }
}

struct CameraPreview: UIViewRepresentable {
    let capture: CameraCapture
    let ultraWide: Bool

    func makeUIView(context: Context) -> PreviewSurface {
        PreviewSurface()
    }

    func updateUIView(_ view: PreviewSurface, context: Context) {
        view.show(ultraWide ? capture.ultraPreview : capture.widePreview)
    }

    final class PreviewSurface: UIView {
        private var preview: AVCaptureVideoPreviewLayer?

        func show(_ layer: AVCaptureVideoPreviewLayer) {
            guard preview !== layer else { return }
            preview?.removeFromSuperlayer()
            preview = layer
            self.layer.addSublayer(layer)
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            preview?.frame = bounds
        }
    }
}
