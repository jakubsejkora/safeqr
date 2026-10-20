import Observation
import SafeQRKit
import Foundation

@MainActor @Observable
final class ResultPresentation: Identifiable {
    let model: ResultModel
    nonisolated var id: UUID { model.id }
    var selectedAction: CodeAction?

    init(model: ResultModel) {
        self.model = model
    }
}
