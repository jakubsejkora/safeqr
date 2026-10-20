import Foundation
import Testing
@testable import SafeQRKit

struct SPDEncoderTests {
    private let iban = "CZ6508000000192000145399"

    @Test func reviewedFieldsRoundTripAndAllOtherFieldsAreDropped() throws {
        let original = "SPD*1.0*ACC:\(iban)+GIBACZPX*AM:250.50*CC:CZK*RN:Example*MSG:Coffee*X-VS:00123*X-SS:456*X-KS:0308*DT:20261025*X-URL:https://example.com*X-UNKNOWN:hidden*PT:IP*ALT-ACC:DE89370400440532013000*NT:E*NN:receipt@example.com*RF:789*X-ID:private*X-PER:7*X-SELF:1"
        let payment = try payment(original)
        let encoded = try SPDEncoder.encode(payment)
        let decoded = try self.payment(encoded)
        #expect(decoded.iban == payment.iban)
        #expect(decoded.bic == payment.bic)
        #expect(decoded.amount == payment.amount)
        #expect(decoded.currency == payment.currency)
        #expect(decoded.recipientName == payment.recipientName)
        #expect(decoded.message == payment.message)
        #expect(decoded.variableSymbol == "00123")
        #expect(decoded.specificSymbol == payment.specificSymbol)
        #expect(decoded.constantSymbol == "0308")
        #expect(decoded.dueDate == payment.dueDate)
        #expect(Set(decoded.fields.keys) == ["ACC", "AM", "CC", "RN", "MSG", "X-VS", "X-SS", "X-KS", "DT"])
        #expect(decoded.paymentURL == nil)
        #expect(decoded.alternateAccounts.isEmpty)
        #expect(decoded.isInstant == nil)
        #expect(decoded.notificationAddress == nil)
    }

    @Test func escapingCannotInjectAnotherFieldAndPreservesLiteralPercentSequences() throws {
        var payment = PaymentRequest(format: .czechSPD)
        payment.iban = iban
        payment.recipientName = "Žofie * 100%"
        payment.message = "Tea*X-URL:https://example.com %2A"
        let encoded = try SPDEncoder.encode(payment)
        let decoded = try self.payment(encoded)
        #expect(encoded.contains("%2A"))
        #expect(encoded.contains("%252A"))
        #expect(encoded.contains("%C5%BD"))
        #expect(decoded.message == payment.message)
        #expect(decoded.recipientName == payment.recipientName)
        #expect(decoded.paymentURL == nil)
        #expect(Set(decoded.fields.keys) == ["ACC", "MSG", "RN"])
    }

    @Test(arguments: [("250", "250"), ("250.50", "250.5"), ("0.01", "0.01"), ("9999999.99", "9999999.99")])
    func amountsUseDotDecimalsWithoutChangingValue(_ example: (String, String)) throws {
        var payment = PaymentRequest(format: .czechSPD)
        payment.iban = iban
        let amount: Decimal = try #require(Decimal(string: example.0, locale: Locale(identifier: "en_US_POSIX")))
        payment.amount = amount
        let encoded = try SPDEncoder.encode(payment)
        #expect(encoded.contains("*AM:" + example.1))
        #expect(try self.payment(encoded).amount == payment.amount)
        #expect(!encoded.contains(","))
    }

    @Test func normalizesAccountAndDoesNotInventOptionalDetails() throws {
        var payment = PaymentRequest(format: .czechSPD)
        payment.iban = "cz65 0800 0000 1920 0014 5399"
        payment.bic = "gibaczpx"
        let encoded = try SPDEncoder.encode(payment)
        #expect(encoded == "SPD*1.0*ACC:\(iban)+GIBACZPX")
    }

    @Test func refusesRoundingInvalidAccountsAndOversizedFields() throws {
        var payment = PaymentRequest(format: .czechSPD)
        payment.iban = iban
        for amount in ["1.001", "-1", "0", "10000000"] {
            let value: Decimal = try #require(Decimal(string: amount))
            payment.amount = value
            #expect(throws: SPDEncoder.EncodingError.self) { try SPDEncoder.encode(payment) }
        }
        payment.amount = nil
        payment.message = String(repeating: "a", count: 61)
        #expect(throws: SPDEncoder.EncodingError.self) { try SPDEncoder.encode(payment) }
        payment.message = nil
        payment.iban = "CZ000000"
        #expect(throws: SPDEncoder.EncodingError.self) { try SPDEncoder.encode(payment) }
        payment.iban = iban
        payment.format = .sepaEPC
        #expect(throws: SPDEncoder.EncodingError.self) { try SPDEncoder.encode(payment) }
    }

    @Test func validPaymentsGetAConfirmedHandoffAndAmbiguousPaymentsDoNot() throws {
        let code = "SPD*1.0*ACC:\(iban)*AM:250*CC:CZK*RN:Example*X-URL:https://example.com"
        let analysis = CodeInspector(locale: Locale(identifier: "en")).inspect(code)
        let action = try #require(analysis.actions.first { if case .sharePayment = $0.kind { true } else { false } })
        #expect(action.title == "Pay in your banking app")
        #expect(action.isPrimary)
        #expect(action.confirmation != nil)
        let ambiguous = CodeInspector().inspect(code + "*AM:500")
        #expect(ambiguous.actions.allSatisfy { $0.confirmation == nil })
        let invoice = CodeInspector().inspect(code.replacingOccurrences(of: "SPD*", with: "SID*"))
        #expect(!invoice.actions.contains { if case .sharePayment = $0.kind { true } else { false } })
    }

    private func payment(_ raw: String) throws -> PaymentRequest {
        let parsed = try #require(PaymentParser.parse(raw))
        guard case .payment(let payment) = parsed.payload else { throw TestError.wrongKind }
        return payment
    }
}
