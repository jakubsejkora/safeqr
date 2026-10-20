import SwiftUI
import Testing
@testable import SafeQR

@Suite @MainActor
struct AppearanceTests {
    @Test(arguments: AppTheme.allCases, [false, true])
    func paletteHasReadableTextAndControls(_ theme: AppTheme, dark: Bool) {
        let palette = theme.palette(dark: dark)
        #expect(contrast(palette.accent, palette.onAccent) >= 4.5)
        #expect(contrast(palette.accent, dark ? 0x1C1C1E : 0xFFFFFF) >= 4.5)
    }

    @Test func preferencesDefaultToGraphiteAndRestoreAppearance() throws {
        let suite = "cz.safeqr.appearance-tests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        #expect(preferences.theme == .graphite)
        #expect(preferences.appearance == .automatic)
        preferences.theme = .plum
        preferences.appearance = .dark
        let reopened = AppPreferences(defaults: defaults)
        #expect(reopened.theme == .plum)
        #expect(reopened.appearance == .dark)
        reopened.appearance = .automatic
        #expect(AppPreferences(defaults: defaults).appearance == .automatic)
        defaults.set("unknown-future-theme", forKey: "theme")
        defaults.set("unknown-future-appearance", forKey: "appearance")
        #expect(AppPreferences(defaults: defaults).theme == .graphite)
        #expect(AppPreferences(defaults: defaults).appearance == .automatic)
    }

    @Test func automaticRemovesTheWindowOverride() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let view = WindowAppearance.AppearanceView()
        window.addSubview(view)
        view.style = AppAppearance.dark.interfaceStyle
        view.apply()
        #expect(window.overrideUserInterfaceStyle == .dark)
        view.style = AppAppearance.light.interfaceStyle
        view.apply()
        #expect(window.overrideUserInterfaceStyle == .light)
        view.style = AppAppearance.automatic.interfaceStyle
        view.apply()
        #expect(window.overrideUserInterfaceStyle == .unspecified)
    }

    private func contrast(_ lhs: UInt32, _ rhs: UInt32) -> Double {
        let a = luminance(lhs), b = luminance(rhs)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ rgb: UInt32) -> Double {
        let channels = [16, 8, 0].map { shift in
            let value = Double((rgb >> shift) & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
}
