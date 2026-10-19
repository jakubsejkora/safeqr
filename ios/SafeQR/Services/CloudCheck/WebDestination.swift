import SafeQRKit

extension CodeAnalysis {
    var hasWebDestination: Bool {
        actions.contains { action in
            guard case .open(let url) = action.kind else { return false }
            return ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        }
    }
}
