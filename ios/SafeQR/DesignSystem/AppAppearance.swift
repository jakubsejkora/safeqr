import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic, light, dark

    var id: Self { self }
    var title: String {
        switch self {
        case .automatic: L10n.text("Automatic")
        case .light: L10n.text("Light")
        case .dark: L10n.text("Dark")
        }
    }
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .automatic: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

struct WindowAppearance: UIViewRepresentable {
    let appearance: AppAppearance
    let theme: AppTheme

    func makeUIView(context: Context) -> AppearanceView { AppearanceView() }

    func updateUIView(_ view: AppearanceView, context: Context) {
        view.style = appearance.interfaceStyle
        view.accent = theme.uiAccent
        view.apply()
    }

    final class AppearanceView: UIView {
        var style = UIUserInterfaceStyle.unspecified
        var accent = AppTheme.graphite.uiAccent

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        func apply() {
            // Resetting to unspecified restores the system appearance after a manual choice.
            window?.overrideUserInterfaceStyle = style
            window?.tintColor = accent
        }
    }
}
