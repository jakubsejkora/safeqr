import AVFoundation
import Observation
import SwiftUI
import SafeQRKit

@MainActor @Observable
final class CameraModel: CameraSource {
    private(set) var state: CameraState = .idle
    private(set) var hasUltraWide = false
    private(set) var hasTorch = false
    var showsUltraWide = false
    private(set) var torchEnabled = false
    private(set) var codes: [TrackedCode] = []
    private(set) var sceneContainsPrivateCodes = false
    private var lastSeen: [UUID: Date] = [:]
    private var acceptsFrames = false
    private(set) var capture: CameraCapture?

    var preview: AnyView {
        if let capture {
            AnyView(CameraPreview(capture: capture, ultraWide: showsUltraWide))
        } else { AnyView(EmptyView()) }
    }

    var unavailableMessage: String {
        if state == .denied {
            return L10n.text("Camera access is off. Allow it in Settings, or choose a picture to check.")
        }
        #if targetEnvironment(simulator)
        return L10n.text("Import a picture to check a code in the Simulator.")
        #else
        return L10n.text("Allow camera access or import a picture to check a code.")
        #endif
    }

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
                case .frame(let observations):
                    guard acceptsFrames else { return }
                    update(observations)
                case .unavailable:
                    state = .unavailable
                case .torchChanged(let enabled):
                    torchEnabled = enabled
                }
            }
        }
        acceptsFrames = true
        capture?.start()
        #endif
    }

    private func update(_ observations: [CameraObservation]) {
        var remaining = codes
        var updated: [TrackedCode] = []
        for observation in observations {
            let match = remaining.enumerated().filter { $0.element.observation.code.raw == observation.code.raw }
                .min { distance($0.element.bounds, observation.code.bounds) < distance($1.element.bounds, observation.code.bounds) }
            if let match {
                var tracked = remaining.remove(at: match.offset)
                tracked.stability.observe(observation.code.bounds)
                tracked.bounds = PreviewGeometry.smooth(observation.code.bounds, from: tracked.bounds)
                if let next = observation.ultraBounds, let previous = tracked.ultraBounds {
                    tracked.ultraBounds = PreviewGeometry.smooth(next, from: previous)
                } else { tracked.ultraBounds = observation.ultraBounds }
                tracked.observation = observation
                updated.append(tracked)
            } else {
                if updated.count < 3 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                updated.append(TrackedCode(observation: observation))
            }
        }
        for code in updated { lastSeen[code.id] = Date() }
        // Brief occlusion should not make the frame or its verdict flicker.
        updated += remaining.filter { Date().timeIntervalSince(lastSeen[$0.id] ?? .distantPast) < 0.65 }
        sceneContainsPrivateCodes = updated.contains { $0.analysis.requiresLocalCheck }
        codes = Array(updated.prefix(3))
        lastSeen = lastSeen.filter { id, _ in codes.contains { $0.id == id } }
    }

    private func distance(_ lhs: CodeBounds, _ rhs: CodeBounds) -> Double {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    func stop() {
        acceptsFrames = false
        codes = []
        lastSeen.removeAll()
        sceneContainsPrivateCodes = false
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
