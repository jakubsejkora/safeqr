import Foundation

/// The on-device result of inspecting one scanned code.
public struct CodeAnalysis: Sendable, Identifiable {
    public let id: UUID
    public let raw: String
    public let symbology: Symbology
    public let content: CodeContent
    public let assessment: RiskAssessment
    public let actions: [CodeAction]

    public init(
        id: UUID = UUID(),
        raw: String,
        symbology: Symbology,
        content: CodeContent,
        assessment: RiskAssessment,
        actions: [CodeAction]
    ) {
        self.id = id
        self.raw = raw
        self.symbology = symbology
        self.content = content
        self.assessment = assessment
        self.actions = actions
    }

    /// Whether the cloud can add evidence the device cannot gather on its own.
    public var benefitsFromCloudCheck: Bool {
        content.kind != .text || assessment.score > 0
    }
}

public enum Symbology: String, Sendable, Codable, CaseIterable {
    case qr, microQR, aztec, dataMatrix, pdf417, other
}

/// What a code contains, already phrased for display.
public struct CodeContent: Sendable {
    public let kind: CodeKind
    public let payload: Payload
    /// Short name of the content type, e.g. "Bank payment".
    public let title: String
    /// One plain sentence describing what the code does.
    public let summary: String
    /// Key details in reading order, e.g. recipient account, amount, message.
    public let facts: [Fact]

    public init(kind: CodeKind, payload: Payload, title: String, summary: String, facts: [Fact]) {
        self.kind = kind
        self.payload = payload
        self.title = title
        self.summary = summary
        self.facts = facts
    }
}

public enum CodeKind: String, Sendable, Codable, CaseIterable {
    case link, payment, crypto, sms, phone, email, wifi, contact, event, location
    case messaging, login, eSIM, appLink, text
}

public struct Fact: Sendable, Hashable, Identifiable {
    public enum Emphasis: Sendable, Hashable {
        case normal, primary, warning
    }

    public let id: String
    public let label: String
    public let value: String
    public let emphasis: Emphasis

    public init(id: String, label: String, value: String, emphasis: Emphasis = .normal) {
        self.id = id
        self.label = label
        self.value = value
        self.emphasis = emphasis
    }
}
