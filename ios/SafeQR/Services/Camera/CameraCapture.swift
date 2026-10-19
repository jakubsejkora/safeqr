@preconcurrency import AVFoundation
import CoreImage
import Vision
import SafeQRKit

enum CaptureEvent: Sendable {
    case ready(hasUltraWide: Bool, hasTorch: Bool)
    case detected(ScannedCode, ScenePhoto?)
    case unavailable
}

// AVFoundation delegates and all mutable capture state are confined to this one serial queue.
final class CameraCapture: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session: AVCaptureSession
    let widePreview = AVCaptureVideoPreviewLayer()
    let ultraPreview = AVCaptureVideoPreviewLayer()
    private let queue = DispatchQueue(label: "cz.safeqr.camera", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let onEvent: @MainActor @Sendable (CaptureEvent) -> Void
    private var wideDevice: AVCaptureDevice?
    private var ultraDevice: AVCaptureDevice?
    private var wideOutput: AVCaptureVideoDataOutput?
    private var ultraOutput: AVCaptureVideoDataOutput?
    private var latestUltra: CVPixelBuffer?
    private var lastUltraTime: CMTime = .zero
    private var lastScanTime: CMTime = .zero
    private var configured = false
    private var frozen = false

    init(onEvent: @escaping @MainActor @Sendable (CaptureEvent) -> Void) {
        self.onEvent = onEvent
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera],
                                                         mediaType: .video, position: .back)
        let pair = discovery.supportedMultiCamDeviceSets.contains { devices in
            devices.contains(where: { $0.deviceType == .builtInWideAngleCamera }) &&
            devices.contains(where: { $0.deviceType == .builtInUltraWideCamera })
        }
        session = AVCaptureMultiCamSession.isMultiCamSupported && pair ? AVCaptureMultiCamSession() : AVCaptureSession()
        super.init()
        widePreview.videoGravity = .resizeAspectFill
        ultraPreview.videoGravity = .resizeAspectFill
    }

    func start() {
        queue.async { [self] in
            do {
                if !configured { try configure() }
                frozen = false
                if !session.isRunning { session.startRunning() }
            } catch {
                emit(.unavailable)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
            latestUltra = nil
        }
    }

    func setTorch(_ enabled: Bool) {
        queue.async { [self] in
            guard let device = wideDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if enabled { try device.setTorchModeOn(level: 0.5) } else { device.torchMode = .off }
            } catch { }
        }
    }

    private func configure() throws {
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ScanError.unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if !(session is AVCaptureMultiCamSession) { session.sessionPreset = .hd1280x720 }
        wideDevice = wide
        wideOutput = try attach(wide, preview: widePreview)
        if session is AVCaptureMultiCamSession,
           let ultra = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            ultraOutput = try? attach(ultra, preview: ultraPreview)
            if ultraOutput != nil { ultraDevice = ultra }
        }
        configured = true
        emit(.ready(hasUltraWide: ultraOutput != nil, hasTorch: wide.hasTorch))
    }

    private func attach(_ device: AVCaptureDevice, preview: AVCaptureVideoPreviewLayer) throws -> AVCaptureVideoDataOutput {
        if session is AVCaptureMultiCamSession {
            guard let format = device.formats.filter({
                $0.isMultiCamSupported && CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 1920 &&
                $0.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 15 && $0.maxFrameRate >= 15 })
            }).max(by: {
                CMVideoFormatDescriptionGetDimensions($0.formatDescription).width < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
            }) else { throw ScanError.unavailable }
            try device.lockForConfiguration()
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
            device.unlockForConfiguration()
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw ScanError.unavailable }
        session.addInputWithNoConnections(input)
        guard let port = input.ports.first(where: { $0.mediaType == .video }) else { throw ScanError.unavailable }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.removeInput(input); throw ScanError.unavailable }
        session.addOutputWithNoConnections(output)
        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        guard session.canAddConnection(connection) else {
            session.removeOutput(output)
            session.removeInput(input)
            throw ScanError.unavailable
        }
        session.addConnection(connection)
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        preview.setSessionWithNoConnection(session)
        let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: preview)
        if session.canAddConnection(previewConnection) {
            session.addConnection(previewConnection)
            if previewConnection.isVideoRotationAngleSupported(90) { previewConnection.videoRotationAngle = 90 }
        }
        return output
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !frozen, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if output === ultraOutput {
            latestUltra = buffer
            lastUltraTime = time
            return
        }
        guard CMTimeGetSeconds(time - lastScanTime) >= 0.25 else { return }
        lastScanTime = time
        let request = BarcodeRequest.make()
        do {
            try VNImageRequestHandler(cvPixelBuffer: buffer).perform([request])
            guard let observation = request.results?.first(where: { $0.payloadStringValue != nil }),
                  let raw = observation.payloadStringValue else { return }
            frozen = true
            let code = ScannedCode(raw: raw, symbology: PhotoScanner.symbology(observation.symbology),
                                   bounds: PhotoScanner.bounds(observation.boundingBox))
            let useUltra = latestUltra != nil && abs(CMTimeGetSeconds(time - lastUltraTime)) < 0.8
            let sceneBuffer = useUltra ? (latestUltra ?? buffer) : buffer
            let image = CIImage(cvPixelBuffer: sceneBuffer)
            let scale = min(1, 1600 / max(image.extent.width, image.extent.height))
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let jpeg = context.createCGImage(scaled, from: scaled.extent).flatMap(PhotoScanner.jpeg)
            let bounds = useUltra ? mappedBounds(code.bounds) : code.bounds
            let scene = jpeg.map { ScenePhoto(jpeg: $0, source: useUltra ? .ultraWideCamera : .camera, bounds: bounds) }
            emit(.detected(code, scene))
            session.stopRunning()
            latestUltra = nil
        } catch { }
    }

    private func mappedBounds(_ bounds: CodeBounds) -> CodeBounds? {
        guard let wideDevice, let ultraDevice else { return nil }
        // Field-of-view mapping is approximate: the two lenses have different optical centres and distortion.
        let wideAngle = Double(wideDevice.activeFormat.videoFieldOfView) * .pi / 360
        let ultraAngle = Double(ultraDevice.activeFormat.videoFieldOfView) * .pi / 360
        let ratio = tan(wideAngle) / tan(ultraAngle)
        guard ratio.isFinite, ratio > 0, ratio < 1 else { return nil }
        return CodeBounds(rect: CGRect(x: 0.5 + (bounds.x - 0.5) * ratio,
                                      y: 0.5 + (bounds.y - 0.5) * ratio,
                                      width: bounds.width * ratio, height: bounds.height * ratio))
    }

    private func emit(_ event: CaptureEvent) {
        Task { @MainActor [onEvent] in onEvent(event) }
    }
}
