#if DEBUG
struct DebugLaunch {
    let screen: String?
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
        medium = arguments.contains("--medium")
        liveCheck = arguments.contains("--live-check")
        liveScene = arguments.contains("--live-scene")
        confirmation = screen != nil && arguments.contains("--confirmation")
        sections = ["journey", "sandbox", "scene"].filter { arguments.contains("--" + $0) }
    }
}
#endif
