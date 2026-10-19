import Foundation
import SafeQRKit

struct CheckConsent: Sendable, Hashable {
    let links: Bool
    let surroundings: Bool

    func request(for analysis: CodeAnalysis, scene: ScenePhoto?) -> CheckRequest? {
        guard links, !analysis.requiresLocalCheck, analysis.benefitsFromCloudCheck, analysis.raw.utf16.count <= 4096 else { return nil }
        let photo = surroundings ? scene : nil
        let hasWebLink = analysis.actions.contains {
            if case .open(let url) = $0.kind {
                return ["https", "http"].contains(url.scheme?.lowercased() ?? "")
            }
            return false
        }
        guard hasWebLink || photo != nil else { return nil }
        return CheckRequest(analysis: analysis, scene: photo)
    }
}

extension CodeAnalysis {
    var requiresLocalCheck: Bool {
        if containsSecrets { return true }
        switch content.payload {
        case .wifi, .login, .eSIM, .contact, .event, .email, .sms, .phone, .messaging, .text: return true
        default: return false
        }
    }
}
