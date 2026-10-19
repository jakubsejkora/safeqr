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
}
