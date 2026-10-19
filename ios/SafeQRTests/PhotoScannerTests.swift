import CoreImage
import Foundation
import Testing
@testable import SafeQR

struct PhotoScannerTests {
    @Test func findsAllCodesInOnePictureWithTopLeftBounds() async throws {
        let context = CIContext()
        let canvas = try #require(CGContext(data: nil, width: 760, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: 760, height: 400))
        let payloads = ["https://example.com/one", "https://example.org/two"]
        for (index, payload) in payloads.enumerated() {
            let filter = try #require(CIFilter(name: "CIQRCodeGenerator"))
            filter.setValue(Data(payload.utf8), forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            let image = try #require(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            let rendered = try #require(context.createCGImage(image, from: image.extent))
            canvas.draw(rendered, in: CGRect(x: 30 + index * 380, y: 40, width: rendered.width, height: rendered.height))
        }
        let renderedCanvas = try #require(canvas.makeImage())
        let jpeg = try #require(PhotoScanner.jpeg(renderedCanvas))
        let scan = try await PhotoScanner.scan(jpeg)
        #expect(Set(scan.codes.map(\.raw)) == Set(payloads))
        #expect(scan.codes.allSatisfy { $0.bounds.x >= 0 && $0.bounds.y >= 0 && $0.bounds.width > 0 && $0.bounds.height > 0 })
        #expect(scan.jpeg.count <= 1_500_000)
    }
}
