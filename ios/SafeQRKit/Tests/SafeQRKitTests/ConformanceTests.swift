import Foundation
import Testing
@testable import SafeQRKit

struct CodeFixture: Decodable, Sendable, CustomTestStringConvertible {
    struct Expected: Decodable, Sendable {
        let kind: CodeKind
        let level: RiskLevel
        let findings: [String]
        let facts: [String: String]
    }
    let id: String
    let raw: String
    let locale: String
    let expected: Expected
    var testDescription: String { id }

    static var all: [CodeFixture] {
        get throws {
            let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let url = package.appendingPathComponent("../../spec/fixtures/codes.json").standardized
            return try JSONDecoder().decode([CodeFixture].self, from: Data(contentsOf: url))
        }
    }
}

struct ConformanceTests {
    @Test(arguments: try CodeFixture.all)
    func sharedFixture(_ fixture: CodeFixture) {
        let result = CodeInspector(locale: Locale(identifier: fixture.locale)).inspect(fixture.raw)
        #expect(result.content.kind == fixture.expected.kind)
        #expect(result.assessment.level == fixture.expected.level)
        #expect(Set(result.assessment.findings.map(\.id)) == Set(fixture.expected.findings))
        for (id, value) in fixture.expected.facts {
            #expect(result.content.facts.first { $0.id == id }?.value == value)
        }
        #expect(result.raw == fixture.raw)
        #expect(!result.assessment.consequences.isEmpty)
        #expect(!result.assessment.limitations.isEmpty)
        for action in result.actions {
            switch action.kind {
            case .copy, .share: #expect(action.confirmation == nil)
            default:
                #expect(action.confirmation != nil)
                #expect(action.isRisky == (result.assessment.level != .safe))
            }
        }
    }
}
