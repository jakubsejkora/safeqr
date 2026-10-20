import Foundation
import SafeQRKit

struct CheckConsent: Sendable, Hashable {
    let links: Bool
    let surroundings: Bool

    func allowsCheck(for analysis: CodeAnalysis, hasScene: Bool) -> Bool {
        links && !analysis.requiresLocalCheck && analysis.benefitsFromCloudCheck && analysis.raw.utf16.count <= 4096
            && (analysis.hasWebDestination || (surroundings && hasScene))
    }

    func request(for analysis: CodeAnalysis, scene: ScenePhoto?) -> CheckRequest? {
        guard allowsCheck(for: analysis, hasScene: scene != nil) else { return nil }
        return CheckRequest(analysis: analysis, scene: surroundings ? scene : nil)
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
