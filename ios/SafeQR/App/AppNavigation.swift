import Observation
import SwiftUI

@MainActor @Observable
final class AppNavigation {
    var tab = AppTab.scan
    var guides: [SafetyGuide] = []
    var result: ResultPresentation?
    var resultDetent = PresentationDetent.medium
}

enum AppTab: Hashable { case scan, help, settings }
