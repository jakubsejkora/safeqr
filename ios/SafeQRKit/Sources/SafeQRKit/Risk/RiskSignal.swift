import Foundation

struct RiskSignal: Sendable {
    let id: String
    let points: Int
    let floor: Int
    let severity: Finding.Severity
    let arguments: [String]
    let detailKey: String

    init(_ id: String, _ points: Int, floor: Int = 0, severity: Finding.Severity? = nil,
         arguments: [String] = [], detailKey: String? = nil) {
        self.id = id
        self.points = points
        self.floor = floor
        self.severity = severity ?? (max(points, floor) >= 70 ? .danger : points >= 20 ? .warning : .info)
        self.arguments = arguments
        self.detailKey = detailKey ?? "finding.\(id).detail"
    }

    func finding(_ localizer: Localizer) -> Finding {
        Finding(id: id, severity: severity, title: localizer.text("finding.\(id).title"),
                detail: localizer.format(detailKey, values: arguments))
    }
}
