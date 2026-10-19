import Foundation
import Testing
@testable import SafeQRKit

struct PaymentParserTests {
    private func payment(_ raw: String) throws -> PaymentRequest {
        let parsed = try #require(PaymentParser.parse(raw))
        guard case .payment(let payment) = parsed.payload else { throw TestError.wrongKind }
        return payment
    }

    @Test func spdEscapingAndStandardFields() throws {
        let raw = "spd*1.0*ACC:CZ6508000000192000145399+GIBACZPX*ALT-ACC:DE89370400440532013000*AM:250.50*CC:CZK*RN:Example*MSG:Tea%2ACoffee%25*RF:123*DT:20261020*PT:IP*NT:E*NN:receipt@example.com*X-VS:123*X-SS:456*X-KS:0308*X-ID:demo*X-URL:https%3A%2F%2Fexample.com*X-PER:7*X-SELF:1"
        let result = try payment(raw)
        #expect(result.iban == "CZ6508000000192000145399")
        #expect(result.bic == "GIBACZPX")
        #expect(result.domesticAccount == "19-2000145399/0800")
        #expect(result.bankName == "Česká spořitelna, a.s.")
        #expect(result.message == "Tea*Coffee%")
        #expect(result.amount == Decimal(string: "250.50"))
        #expect(result.isInstant == true)
        #expect(result.notificationAddress == "receipt@example.com")
        #expect(result.retryDays == 7)
        #expect(result.isSelfPayment == true)
        #expect(result.fields["X-URL"] == "https://example.com")
    }

    @Test func spdCanonicalCRC() throws {
        let raw = "SPD*1.0*CC:CZK*ACC:CZ5855000000001265098001*AM:100.00*CRC32:AAD80227"
        #expect(try payment(raw).checksum == .valid)
        #expect(try payment(raw.replacingOccurrences(of: "100.00", with: "100.01")).checksum == .invalid)
        #expect(try payment(raw + "*").checksum == .valid)
    }

    @Test func epcKeepsEmptyLinesAndBothVersions() throws {
        let v2 = "BCD\n002\n1\nSCT\n\nExample\nDE89370400440532013000\nEUR12.34\n\n\nCoffee\nInformation"
        let result = try payment(v2)
        #expect(result.bic == nil)
        #expect(result.recipientName == "Example")
        #expect(result.message == "Coffee")
        #expect(result.amount == Decimal(string: "12.34"))
        #expect(PaymentParser.parse(v2)?.issues.isEmpty == true)
        let v1 = v2.replacingOccurrences(of: "002\n", with: "001\n").replacingOccurrences(of: "SCT\n\n", with: "SCT\nCOBADEFFXXX\n")
        #expect(PaymentParser.parse(v1)?.issues.isEmpty == true)
        #expect(PaymentParser.parse(v1.replacingOccurrences(of: "COBADEFFXXX", with: ""))?.issues.contains(.malformed) == true)
    }

    @Test func emvCRCAndTruncatedTLV() throws {
        let raw = "0002010216example-merchant5204599953032035406250.005802CZ5907Example6006Prague6304"
        let valid = raw + String(format: "%04X", Checksums.crc16(raw.utf8))
        let result = try payment(valid)
        #expect(result.checksum == .valid)
        #expect(result.currency == "CZK")
        #expect(result.recipientName == "Example")
        #expect(try payment(valid.replacingOccurrences(of: "250.00", with: "251.00")).checksum == .invalid)
        #expect(PaymentParser.parse("0002015999X")?.issues.contains(.malformed) == true)
    }

    @Test func checksumsHaveIndependentVectors() {
        #expect(Checksums.crc16("123456789".utf8) == 0x29B1)
        #expect(Checksums.crc32("123456789".utf8) == 0xCBF43926)
    }

    @Test(arguments: ["CZ6508000000192000145399", "DE89370400440532013000", "GB82 WEST 1234 5698 7654 32", "CH9300762011623852957"])
    func validIBANs(_ iban: String) {
        #expect(IBAN.isValid(iban))
    }

    @Test(arguments: ["CZ6508000000192000145398", "CZ650800000019200014539", "GB00WEST12345698765432", "💥", "ZZ12123456789012345678"])
    func invalidIBANs(_ iban: String) {
        #expect(!IBAN.isValid(iban))
    }

    @Test func duplicatePaymentFieldsDoNotDisappear() throws {
        let raw = "SPD*1.0*ACC:CZ6508000000192000145399*AM:250*AM:250000*CC:CZK"
        #expect(PaymentParser.parse(raw)?.issues.contains(.ambiguous) == true)
        let result = CodeInspector(locale: Locale(identifier: "en")).inspect(raw)
        #expect(result.assessment.floor == 70)
        #expect(result.actions.allSatisfy { $0.confirmation == nil })
    }
}

enum TestError: Error { case wrongKind }
