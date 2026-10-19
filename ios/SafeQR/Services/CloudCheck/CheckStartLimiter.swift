import Foundation

struct CheckStartBudget {
    private var starts: [Date] = []
    private var cooldown = Date.distantPast

    mutating func reserve(at now: Date) -> TimeInterval {
        starts.removeAll { now.timeIntervalSince($0) >= 60 }
        let quotaDelay = starts.count >= 12 ? (starts.first?.addingTimeInterval(60).timeIntervalSince(now) ?? 0) : 0
        let delay = max(0, cooldown.timeIntervalSince(now), quotaDelay)
        if delay == 0 { starts.append(now) }
        return delay
    }

    mutating func postpone(until date: Date) { cooldown = max(cooldown, date) }
}

actor CheckStartLimiter {
    private var budget = CheckStartBudget()

    func acquire() async throws {
        while true {
            try Task.checkCancellation()
            let delay = budget.reserve(at: Date())
            if delay == 0 { return }
            try await Task.sleep(for: .seconds(delay))
        }
    }

    func postpone(seconds: TimeInterval) {
        budget.postpone(until: Date().addingTimeInterval(max(1, seconds)))
    }
}
