import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

@Suite @MainActor
struct PaymentHandoffTests {
    @Test func sharedImageDecodesToOnlyTheReviewedPaymentDetails() async throws {
        let raw = "SPD*1.0*ACC:CZ6508000000192000145399+GIBACZPX*AM:250.50*CC:CZK*RN:Example*MSG:Tea%2ACoffee%25*X-VS:123*X-URL:https://example.com*X-EXTRA:secret"
        let analysis = CodeInspector().inspect(raw)
        let action = try #require(analysis.actions.first { if case .sharePayment = $0.kind { true } else { false } })
        #expect(action.isHandoff)
        #expect(HandoffURLBuilder.url(for: action.kind) == nil)
        let handler = ActionHandler()
        await handler.perform(action, payload: analysis.content.payload)
        guard case .paymentImage(let image) = handler.presentation else {
            Issue.record("Expected a freshly generated payment QR image")
            return
        }
        let data = try #require(image.pngData())
        let scan = try await PhotoScanner.scan(data)
        let encoded = try #require(scan.codes.first?.raw)
        guard case .payment(let payment) = analysis.content.payload else { throw HandoffError.invalid }
        #expect(encoded == (try SPDEncoder.encode(payment)))
        #expect(!encoded.contains("X-URL"))
        #expect(!encoded.contains("X-EXTRA"))
        #expect(scan.codes.count == 1)
        #expect(image.size.width <= 1024)
    }

    @Test func riskStillControlsThePaymentConfirmation() throws {
        let analysis = CodeInspector().inspect("SPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example*X-URL:https://xn--pple-43d.test")
        let model = ResultModel(analysis: analysis, scene: nil)
        let action = try #require(model.actions.first { if case .sharePayment = $0.kind { true } else { false } })
        #expect(action.confirmation != nil)
        #expect(action.isRisky)
        #expect(model.handoffLevel == analysis.assessment.level)
        #expect(model.handoffLevel != .safe)
    }
}
