import Foundation
import SafeQRKit
import Vision

/// A photo can expose a private code even when a different code was selected.
enum ScenePrivacy {
    static func allowsUpload(_ jpeg: Data, selectedPayload: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard jpeg.count <= 1_500_000 else { return false }
            let request = BarcodeRequest.make()
            do { try VNImageRequestHandler(data: jpeg).perform([request]) }
            catch { return false }
            guard let observations = request.results,
                  observations.contains(where: { $0.payloadStringValue == selectedPayload }) else { return false }
            let inspector = CodeInspector()
            // Unreadable codes and uncertain redaction boundaries must not expose a private code.
            return observations.allSatisfy { observation in
                guard let raw = observation.payloadStringValue, !raw.isEmpty else { return false }
                return !inspector.inspect(raw, symbology: PhotoScanner.symbology(observation.symbology)).requiresLocalCheck
            }
        }.value
    }

    static func containsPrivateCodes(_ codes: [ScannedCode]) -> Bool {
        let inspector = CodeInspector(locale: L10n.locale)
        return codes.contains { inspector.inspect($0.raw, symbology: $0.symbology).requiresLocalCheck }
    }
}
