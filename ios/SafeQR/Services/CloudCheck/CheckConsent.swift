import Foundation
import SafeQRKit

struct CheckConsent: Sendable, Hashable {
    let links: Bool
    let surroundings: Bool

    func request(for analysis: CodeAnalysis, scene: ScenePhoto?) -> CheckRequest? {
        guard links, analysis.benefitsFromCloudCheck, analysis.raw.utf16.count <= 4096 else { return nil }
        // Authentication secrets and personal records must stay on the phone, even when link checks are enabled.
        switch analysis.content.payload {
        case .wifi, .login, .eSIM, .contact, .event, .email, .sms, .phone, .text:
            return nil
        default:
            break
        }
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
