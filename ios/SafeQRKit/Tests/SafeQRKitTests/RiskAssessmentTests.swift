import Foundation
import Testing
@testable import SafeQRKit

struct RiskAssessmentTests {
    @Test(arguments: ["http://www.vodafone.cz", "http://www.parkujvklidu.cz", "http://example.com"])
    func httpRemainsCautionOfflineButCanBeClearedByCloud(_ address: String) {
        let device = CodeInspector(locale: Locale(identifier: "en")).inspect(address).assessment
        #expect(device.score == 30)
        #expect(device.level == .caution)
        #expect(device.floor == 0)
        #expect(device.findings.contains { $0.id == "link.http" && $0.severity == .warning })

        let merged = device.merged(with: RemoteAssessment(score: 5, findings: [], consequences: [], limitations: []))
        #expect(merged.score == 5)
        #expect(merged.level == .safe)
        #expect(merged.findings.contains { $0.id == "link.http" })
    }

    @Test func httpDoesNotRemoveOtherProvenFloors() {
        let device = CodeInspector().inspect("http://bank.example@example.com").assessment
        #expect(device.score == 100)
        #expect(device.floor == 70)
        let merged = device.merged(with: RemoteAssessment(score: 0, findings: [], consequences: [], limitations: []))
        #expect(merged.score == 70)
        #expect(merged.level == .danger)
    }

    @Test func remoteVerdictCannotDropBelowDeviceFloor() {
        let device = RiskAssessment(score: 80, floor: 70, findings: [], consequences: [], limitations: [])
        let remote = RemoteAssessment(score: 10, findings: [], consequences: [], limitations: [])

        #expect(device.merged(with: remote).score == 70)
    }

    @Test func remoteVerdictCanRaiseRisk() {
        let device = RiskAssessment(score: 20, findings: [], consequences: [], limitations: [])
        let remote = RemoteAssessment(score: 90, findings: [], consequences: [], limitations: [])

        #expect(device.merged(with: remote).level == .danger)
    }

    @Test func remoteVerdictPreservesDeviceLimitationsWithoutDuplicates() {
        let device = RiskAssessment(score: 40, floor: 30, findings: [], consequences: [],
                                    limitations: ["Account ownership is unknown.", "Check the recipient."])
        let remote = RemoteAssessment(score: 10, findings: [], consequences: [],
                                      limitations: ["Check the recipient.", "The website could not be reached."])
        let merged = device.merged(with: remote)
        #expect(merged.limitations == ["Account ownership is unknown.", "Check the recipient.", "The website could not be reached."])
        #expect(merged.score == 30)
        #expect(device.merged(with: RemoteAssessment(score: 10, findings: [], consequences: [], limitations: [])).limitations == device.limitations)
    }
}
