import CoreML
import Vision

enum BarcodeRequest {
    static func make() -> VNDetectBarcodesRequest {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr, .microQR, .aztec, .dataMatrix, .pdf417, .microPDF417]
        #if targetEnvironment(simulator)
        request.revision = VNDetectBarcodesRequest.supportedRevisions.first ?? request.revision
        let supported = (try? request.supportedSymbologies()) ?? []
        request.symbologies = request.symbologies.filter { supported.contains($0) }
        // Newer Vision revisions cannot infer barcodes on the iOS 26.5 Simulator. Real devices keep the current revision.
        if let cpu = MLComputeDevice.allComputeDevices.first(where: {
            if case .cpu = $0 { return true }
            return false
        }) {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        return request
    }
}
