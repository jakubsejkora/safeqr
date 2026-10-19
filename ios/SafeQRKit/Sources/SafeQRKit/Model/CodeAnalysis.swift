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
        !containsSecrets && !assessment.findings.contains { ["code.tooLarge", "content.tooMany"].contains($0.id) }
            && (content.kind != .text || assessment.score > 0)
    }

    /// Known authentication or installation secrets, including those embedded in another payload.
    public var containsSecrets: Bool {
        if Self.isSecret(content.payload) { return true }
        if assessment.findings.contains(where: { $0.id.hasPrefix("login.") || $0.id == "esim.activation" }) { return true }
        guard assessment.findings.contains(where: { $0.id == "content.combination" }) else { return false }
        return EmbeddedPayloads.inspect(content.payload, raw: raw).codes.contains { Self.isSecret($0.payload) }
    }

    private static func isSecret(_ payload: Payload) -> Bool {
        switch payload {
        case .login, .eSIM: true
        case .wifi(let network): network.password != nil
        case .link(let url), .appLink(let url): hasCredentials(url)
        case .messaging(let link): hasCredentials(link.url)
        default: false
        }
    }

    private static func hasCredentials(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.user != nil || components?.password != nil { return true }
        let keys: Set<String> = ["password", "passwd", "secret", "access_token", "id_token", "refresh_token", "api_key", "private_key"]
        return ParseSupport.query(url.absoluteString).fields.keys.contains { keys.contains($0.lowercased()) }
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
