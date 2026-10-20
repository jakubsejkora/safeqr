import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case graphite, blue, indigo, plum, cocoa, forest

    var id: Self { self }
    var title: String {
        switch self {
        case .graphite: L10n.text("Graphite")
        case .blue: L10n.text("Blue")
        case .indigo: L10n.text("Indigo")
        case .plum: L10n.text("Plum")
        case .cocoa: L10n.text("Cocoa")
        case .forest: L10n.text("Forest")
        }
    }

    var iconName: String? { self == .graphite ? nil : "AppIcon" + rawValue.capitalized }
    var previewName: String { "Theme" + rawValue.capitalized }

    func palette(dark: Bool) -> ThemePalette {
        let pair: (UInt32, UInt32)
        switch self {
        case .graphite: pair = (0x202124, 0xE5E7EB)
        case .blue: pair = (0x0066CC, 0x64B5FF)
        case .indigo: pair = (0x5141A3, 0xB7AAFF)
        case .plum: pair = (0x77506C, 0xD4ABC9)
        case .cocoa: pair = (0x735845, 0xD9BBA2)
        case .forest: pair = (0x246E61, 0x99D6C1)
        }
        return ThemePalette(accent: dark ? pair.1 : pair.0, onAccent: dark ? 0x111214 : 0xFFFFFF)
    }

    var uiAccent: UIColor { UIColor { traits in UIColor(rgb: palette(dark: traits.userInterfaceStyle == .dark).accent) } }
    var accent: Color { Color(uiColor: uiAccent) }
    var onAccent: Color {
        Color(uiColor: UIColor { traits in UIColor(rgb: palette(dark: traits.userInterfaceStyle == .dark).onAccent) })
    }
}

struct ThemePalette: Sendable {
    let accent: UInt32
    let onAccent: UInt32
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 255) / 255,
                  green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}

extension EnvironmentValues {
    @Entry var appTheme: AppTheme = .graphite
}
