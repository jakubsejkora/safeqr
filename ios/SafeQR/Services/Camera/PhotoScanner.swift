import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision
import SafeQRKit

struct ScannedCode: Identifiable, Sendable {
    let id = UUID()
    let raw: String
    let symbology: Symbology
    let bounds: CodeBounds
}

struct ImportedScan: Sendable {
    let codes: [ScannedCode]
    let jpeg: Data
}

enum PhotoScanner {
    static func scan(_ data: Data) async throws -> ImportedScan {
        try await Task.detached(priority: .userInitiated) {
            guard data.count <= 40_000_000,
                  let image = thumbnail(data, maxPixels: 2400) else { throw ScanError.invalidImage }
            let request = BarcodeRequest.make()
            try VNImageRequestHandler(cgImage: image).perform([request])
            let codes = (request.results ?? []).compactMap { observation -> ScannedCode? in
                guard let raw = observation.payloadStringValue, !raw.isEmpty else { return nil }
                return ScannedCode(raw: raw, symbology: symbology(observation.symbology),
                                   bounds: bounds(observation.boundingBox))
            }
            guard !codes.isEmpty else { throw ScanError.noCodes }
            guard let scene = thumbnail(data, maxPixels: 1600), let jpeg = jpeg(scene) else { throw ScanError.invalidImage }
            return ImportedScan(codes: codes, jpeg: jpeg)
        }.value
    }

    static func symbology(_ value: VNBarcodeSymbology) -> Symbology {
        switch value {
        case .qr: .qr
        case .microQR: .microQR
        case .aztec: .aztec
        case .dataMatrix: .dataMatrix
        case .pdf417, .microPDF417: .pdf417
        default: .other
        }
    }

    static func bounds(_ visionRect: CGRect) -> CodeBounds {
        CodeBounds(rect: CGRect(x: visionRect.minX, y: 1 - visionRect.maxY,
                               width: visionRect.width, height: visionRect.height))
    }

    static func jpeg(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        guard CGImageDestinationFinalize(destination), data.length <= 1_500_000 else { return nil }
        return data as Data
    }

    private static func thumbnail(_ data: Data, maxPixels: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ] as CFDictionary)
    }
}

enum ScanError: Error {
    case invalidImage, noCodes, unavailable

    var message: String {
        switch self {
        case .invalidImage: L10n.text("This picture could not be read. Try a different photo.")
        case .noCodes: L10n.text("No code found. Choose a clearer picture with the whole code visible.")
        case .unavailable: L10n.text("The camera is unavailable. You can still import a photo.")
        }
    }
}
