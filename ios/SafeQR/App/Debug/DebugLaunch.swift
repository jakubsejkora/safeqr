#if DEBUG
struct DebugLaunch {
    let screen: String?
    let theme: AppTheme?
    let appearance: AppAppearance?
    let zoom: CameraZoom?
    let medium: Bool
    let liveCheck: Bool
    let liveScene: Bool
    let confirmation: Bool
    let sections: [String]

    init(arguments: [String]) {
        if let index = arguments.firstIndex(of: "--screen"), arguments.indices.contains(index + 1),
           !arguments[index + 1].hasPrefix("-") {
            screen = arguments[index + 1]
        } else { screen = nil }
        theme = Self.value(after: "--theme", in: arguments).flatMap(AppTheme.init(rawValue:))
        appearance = Self.value(after: "--appearance", in: arguments).flatMap(AppAppearance.init(rawValue:))
        zoom = Self.value(after: "--zoom", in: arguments).flatMap(Double.init).flatMap(CameraZoom.init(rawValue:))
        medium = arguments.contains("--medium")
        liveCheck = arguments.contains("--live-check")
        liveScene = arguments.contains("--live-scene")
        confirmation = screen != nil && arguments.contains("--confirmation")
        sections = ["journey", "sandbox", "scene"].filter { arguments.contains("--" + $0) }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
