struct ScannerHintTiming {
    private var idleSince: ContinuousClock.Instant?

    mutating func update(hasCode: Bool, at now: ContinuousClock.Instant = .now) -> Bool {
        if hasCode {
            idleSince = nil
            return false
        }
        guard let idleSince else {
            self.idleSince = now
            return false
        }
        return idleSince.duration(to: now) >= .seconds(5)
    }
}
