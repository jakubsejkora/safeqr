#if DEBUG
import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

struct DebugSampleTests {
    @Test(arguments: ["en", "cs"])
    func samplesCoverEveryKindAndRequiredRiskCombinations(_ language: String) {
        let inspector = CodeInspector(locale: Locale(identifier: language))
        let analyses = DebugSample.allCases.map { inspector.inspect($0.raw) }
        #expect(Set(analyses.map(\.content.kind)) == Set(CodeKind.allCases))
        #expect(analyses.allSatisfy { !$0.content.title.isEmpty && !$0.content.summary.isEmpty })
        for sample in [DebugSample.premiumSMS, .forwarding, .login, .authExport, .esim, .enterprise, .lookalike] {
            #expect(inspector.inspect(sample.raw).assessment.level == .danger)
        }
        for sample in [DebugSample.paymentLink, .bankContact, .wifi, .premiumCall] {
            #expect(inspector.inspect(sample.raw).assessment.level == .caution)
        }
    }
}
#endif
