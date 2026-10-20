@preconcurrency import AVFoundation
import CoreImage
import Vision
import SafeQRKit

enum CaptureEvent: Sendable {
    case ready(hasUltraWide: Bool, hasTorch: Bool, maximumMainZoom: CGFloat)
    case frame([CameraObservation], zoomRevision: Int)
    case zoomChanged(CameraZoom, revision: Int)
    case torchChanged(Bool)
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
    private var latestWide: CVPixelBuffer?
    private var lastUltraTime: CMTime = .zero
    private var lastScanTime: CMTime = .zero
    private var configured = false
    private var zoom: CameraZoom = .main
    private var zoomRevision = 0
    private var validFramesAfter: CMTime = .invalid

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
            latestWide = nil
        }
    }

    func frozenFrame(ultraWide: Bool) async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                let buffer = ultraWide ? latestUltra ?? latestWide : latestWide
                let image = buffer.flatMap { buffer in
                    let image = CIImage(cvPixelBuffer: buffer)
                    return context.createCGImage(image, from: image.extent)
                }
                continuation.resume(returning: image)
            }
        }
    }

    func setTorch(_ enabled: Bool) {
        queue.async { [self] in
            guard let device = wideDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if enabled { try device.setTorchModeOn(level: 0.5) } else { device.torchMode = .off }
                emit(.torchChanged(device.torchMode == .on))
            } catch {
                emit(.torchChanged(device.torchMode == .on))
            }
        }
    }

    func setZoom(_ requested: CameraZoom, revision: Int) {
        queue.async { [self] in
            guard let device = wideDevice else { return }
            zoomRevision = revision
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                guard requested.mainFactor >= device.minAvailableVideoZoomFactor,
                      requested.mainFactor <= device.maxAvailableVideoZoomFactor,
                      requested != .ultraWide || ultraDevice != nil else {
                    emit(.zoomChanged(zoom, revision: revision))
                    return
                }
                device.videoZoomFactor = requested.mainFactor
                zoom = requested
                // Do not reuse detections from frames queued before the sensor crop changed.
                if let clock = session.synchronizationClock {
                    validFramesAfter = CMClockGetTime(clock) + CMTime(seconds: 0.15, preferredTimescale: 600)
                }
                lastScanTime = .zero
                emit(.zoomChanged(zoom, revision: revision))
            } catch {
                emit(.zoomChanged(zoom, revision: revision))
            }
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
        emit(.ready(hasUltraWide: ultraOutput != nil, hasTorch: wide.hasTorch,
                    maximumMainZoom: wide.maxAvailableVideoZoomFactor))
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
        guard let port = input.ports.first(where: { $0.mediaType == .video }) else {
            session.removeInput(input)
            throw ScanError.unavailable
        }
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
        if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
        preview.setSessionWithNoConnection(session)
        let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: preview)
        if session.canAddConnection(previewConnection) {
            session.addConnection(previewConnection)
            if previewConnection.isVideoRotationAngleSupported(90) { previewConnection.videoRotationAngle = 90 }
            if previewConnection.isVideoStabilizationSupported { previewConnection.preferredVideoStabilizationMode = .off }
        }
        return output
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if output === ultraOutput {
            latestUltra = buffer
            lastUltraTime = time
            return
        }
        latestWide = buffer
        if validFramesAfter.isValid, time < validFramesAfter { return }
        guard CMTimeGetSeconds(time - lastScanTime) >= 0.25 else { return }
        lastScanTime = time
        let request = BarcodeRequest.make()
        // A failed frame is retried on the next capture.
        try? VNImageRequestHandler(cvPixelBuffer: buffer).perform([request])
        let useUltra = latestUltra != nil && abs(CMTimeGetSeconds(time - lastUltraTime)) < 0.8
        let sceneBuffer = useUltra ? (latestUltra ?? buffer) : buffer
        let sceneImage = CIImage(cvPixelBuffer: sceneBuffer)
        let observations = (request.results ?? []).filter { $0.payloadStringValue != nil }
        let jpeg = observations.isEmpty ? nil : encode(sceneImage, longestSide: 1600)
        let codes = observations.compactMap { observation -> CameraObservation? in
            guard let raw = observation.payloadStringValue else { return nil }
            let code = ScannedCode(raw: raw, symbology: PhotoScanner.symbology(observation.symbology),
                                   bounds: PhotoScanner.bounds(observation.boundingBox))
            let frameSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
            let ultraBounds = useUltra ? mappedBounds(code.bounds, wideSize: frameSize, ultraSize: sceneImage.extent.size) : nil
            let scene = jpeg.map { ScenePhoto(jpeg: $0, source: useUltra ? .ultraWideCamera : .camera,
                                              bounds: useUltra ? ultraBounds : code.bounds) }
            return CameraObservation(code: code, scene: scene,
                                     frameSize: frameSize,
                                     ultraBounds: ultraBounds, ultraSize: sceneImage.extent.size)
        }
        emit(.frame(codes, zoomRevision: zoomRevision))
    }

    private func encode(_ image: CIImage, longestSide: CGFloat) -> Data? {
        let scale = min(1, longestSide / max(image.extent.width, image.extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return context.createCGImage(scaled, from: scaled.extent).flatMap(PhotoScanner.jpeg)
    }

    private func mappedBounds(_ bounds: CodeBounds, wideSize: CGSize, ultraSize: CGSize) -> CodeBounds? {
        guard let wideDevice, let ultraDevice else { return nil }
        // Field-of-view mapping is approximate: the two lenses have different optical centres and distortion.
        return PreviewGeometry.ultraWideBounds(bounds, wideSize: wideSize, ultraSize: ultraSize,
            wideFieldOfView: fieldOfView(wideDevice), ultraFieldOfView: fieldOfView(ultraDevice),
            mainZoom: Double(wideDevice.videoZoomFactor))
    }

    private func fieldOfView(_ device: AVCaptureDevice) -> Double {
        Double(device.isGeometricDistortionCorrectionEnabled
               ? device.activeFormat.geometricDistortionCorrectedVideoFieldOfView : device.activeFormat.videoFieldOfView)
    }

    private func emit(_ event: CaptureEvent) {
        Task { @MainActor [onEvent] in onEvent(event) }
    }
}
