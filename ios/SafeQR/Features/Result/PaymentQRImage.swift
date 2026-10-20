import CoreImage
import UIKit
import SafeQRKit

enum PaymentQRImage {
    static func make(_ payment: PaymentRequest) throws -> UIImage {
        let payload = try SPDEncoder.encode(payment)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { throw HandoffError.invalid }
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let code = filter.outputImage,
              let modules = CIContext(options: [.cacheIntermediates: false]).createCGImage(code, from: code.extent) else {
            throw HandoffError.invalid
        }
        let scale = max(1, 1024 / (modules.width + 8))
        let side = (modules.width + 8) * scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { renderer in
            UIColor.white.setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: side, height: side))
            renderer.cgContext.interpolationQuality = .none
            UIImage(cgImage: modules).draw(in: CGRect(x: 4 * scale, y: 4 * scale,
                                                     width: modules.width * scale, height: modules.height * scale))
        }
    }
}
