import Foundation

struct CodeStability {
    private var anchor: CodeBounds
    private var since: Date

    init(bounds: CodeBounds, now: Date = Date()) {
        anchor = bounds
        since = now
    }

    mutating func observe(_ bounds: CodeBounds, at now: Date = Date()) {
        let movement = max(abs(bounds.x - anchor.x), abs(bounds.y - anchor.y),
                           abs(bounds.width - anchor.width), abs(bounds.height - anchor.height))
        if movement > 0.025 { anchor = bounds; since = now }
    }

    func isSteady(at now: Date) -> Bool { now >= since.addingTimeInterval(0.8) }
}
