#if DEBUG
import SwiftUI

struct DebugResultView: View {
    @Environment(AppServices.self) private var services
    @Environment(DebugLaunchConfiguration.self) private var launch
    let presentation: ResultPresentation
    let compact: Bool

    var body: some View {
        ScrollViewReader { scroll in
            ResultView(presentation: presentation, compact: compact)
                .task(id: presentation.model.verdict != nil) {
                    guard presentation.model.verdict != nil else { return }
                    // Evidence anchors are registered after the verdict's view update.
                    do { try await Task.sleep(for: .milliseconds(150)) }
                    catch { return }
                    for section in launch.options.sections { scroll.scrollTo(section, anchor: .top) }
                }
        }
        .task { await launch.prepareConfirmation(in: services) }
    }
}
#endif
