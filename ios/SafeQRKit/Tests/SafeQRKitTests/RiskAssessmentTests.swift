import Testing
@testable import SafeQRKit

struct RiskAssessmentTests {
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
