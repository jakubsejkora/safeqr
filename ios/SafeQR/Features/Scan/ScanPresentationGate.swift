import Foundation

struct ScanPresentationGate {
    enum Decision: Equatable {
        case single(UUID)
        case chooser
    }

    private var blocked: Set<String> = []
    private var absentSince: [String: Date] = [:]

    mutating func decision(for codes: [TrackedCode], at now: Date = Date()) -> Decision? {
        let visible = Set(codes.map(\.analysis.raw))
        for raw in blocked {
            if visible.contains(raw) {
                absentSince[raw] = nil
            } else if let since = absentSince[raw] {
                if now.timeIntervalSince(since) >= 1 {
                    blocked.remove(raw)
                    absentSince[raw] = nil
                }
            } else {
                absentSince[raw] = now
            }
        }
        guard codes.contains(where: { !blocked.contains($0.analysis.raw) }) else { return nil }
        if codes.count > 1 { return .chooser }
        guard let code = codes.first, code.stability.isSteady(at: now) else { return nil }
        return .single(code.id)
    }

    mutating func presented(_ codes: [TrackedCode]) {
        blocked.formUnion(codes.map(\.analysis.raw))
        absentSince.removeAll()
    }

    mutating func presented(_ raw: String) {
        blocked.insert(raw)
        absentSince.removeAll()
    }

    mutating func resumed() {
        // Time behind a frozen sheet is not evidence that a code left the camera.
        absentSince.removeAll()
    }

    static func mayBeOverlaid(_ codes: [TrackedCode]) -> Bool {
        guard codes.count == 2 else { return false }
        let first = codes[0].bounds
        let second = codes[1].bounds
        let a = CGRect(x: first.x, y: first.y, width: first.width, height: first.height)
        let b = CGRect(x: second.x, y: second.y, width: second.width, height: second.height)
        let margin = min(0.08, max(min(a.width, a.height), min(b.width, b.height)) * 0.35)
        return a.insetBy(dx: -margin, dy: -margin).intersects(b)
    }
}
