import Foundation

/// A 0–100 risk score with the reasons behind it.
public struct RiskAssessment: Sendable, Hashable {
    /// 0 means no known risk, 100 means almost certainly harmful.
    public let score: Int
    /// The lowest score any later evidence may lower this assessment to.
    /// Hard device rules set it so a remote verdict can raise risk freely but never hide a proven danger.
    public let floor: Int
    public let findings: [Finding]
    /// What happens if the person continues, in plain language.
    public let consequences: [String]
    /// What could not be checked, in plain language.
    public let limitations: [String]

    public init(score: Int, floor: Int = 0, findings: [Finding], consequences: [String], limitations: [String]) {
        self.score = score.clamped(to: 0...100)
        self.floor = floor.clamped(to: 0...self.score)
        self.findings = findings
        self.consequences = consequences
        self.limitations = limitations
    }

    public var level: RiskLevel { RiskLevel(score: score) }
}

public enum RiskLevel: String, Sendable, Codable, CaseIterable {
    case safe, caution, danger

    public init(score: Int) {
        switch score {
        case ..<30: self = .safe
        case ..<70: self = .caution
        default: self = .danger
        }
    }
}

public struct Finding: Sendable, Hashable, Identifiable {
    public enum Severity: String, Sendable, Codable, Comparable {
        case info, warning, danger

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rank < rhs.rank
        }

        private var rank: Int {
            switch self {
            case .info: 0
            case .warning: 1
            case .danger: 2
            }
        }
    }

    public enum Source: String, Sendable, Codable {
        case device, sandbox, scene, intel, ai
    }

    /// Stable rule identifier, e.g. `link.punycode`.
    public let id: String
    public let severity: Severity
    public let title: String
    public let detail: String
    public let source: Source

    public init(id: String, severity: Severity, title: String, detail: String, source: Source = .device) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
        self.source = source
    }
}

/// Evidence gathered off-device: link sandbox, scene analysis, threat intelligence.
public struct RemoteAssessment: Sendable, Hashable {
    public let score: Int
    public let findings: [Finding]
    public let consequences: [String]
    public let limitations: [String]

    public init(score: Int, findings: [Finding], consequences: [String], limitations: [String]) {
        self.score = score.clamped(to: 0...100)
        self.findings = findings
        self.consequences = consequences
        self.limitations = limitations
    }
}

extension RiskAssessment {
    /// Combines device and remote evidence. The remote score wins, but never below the device floor.
    public func merged(with remote: RemoteAssessment) -> RiskAssessment {
        RiskAssessment(
            score: max(remote.score, floor),
            floor: floor,
            findings: (findings + remote.findings).uniqued(by: \.id).sorted { $0.severity > $1.severity },
            consequences: remote.consequences.isEmpty ? consequences : remote.consequences,
            limitations: remote.limitations
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Sequence {
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}
