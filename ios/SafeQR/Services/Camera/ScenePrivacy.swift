import SafeQRKit

/// A photo can expose a private code even when a different code was selected.
enum ScenePrivacy {
    static func containsPrivateCodes(_ codes: [ScannedCode]) -> Bool {
        let inspector = CodeInspector(locale: L10n.locale)
        return codes.contains { inspector.inspect($0.raw, symbology: $0.symbology).requiresLocalCheck }
    }
}
