#if DEBUG
import Foundation

enum DebugLaunch {
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

#endif
