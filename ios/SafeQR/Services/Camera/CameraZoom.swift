import Foundation

enum CameraZoom: Double, CaseIterable, Identifiable, Sendable {
    case ultraWide = 0.5
    case main = 1
    case double = 2

    var id: Self { self }
    var mainFactor: CGFloat { self == .double ? 2 : 1 }
    var accessibilityLabel: String {
        switch self {
        case .ultraWide: L10n.text("Ultra wide")
        case .main: L10n.text("Main camera")
        case .double: L10n.text("2× zoom")
        }
    }

    func title(selected: Bool) -> String {
        switch self {
        case .ultraWide: L10n.text(selected ? "0.5×" : "0.5")
        case .main: L10n.text(selected ? "1×" : "1")
        case .double: L10n.text(selected ? "2×" : "2")
        }
    }

    static func available(ultraWide: Bool, maximumMainZoom: CGFloat) -> [Self] {
        (ultraWide ? [.ultraWide] : []) + [.main] + (maximumMainZoom >= 2 ? [.double] : [])
    }
}
