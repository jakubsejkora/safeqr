import Foundation
import Testing
@testable import SafeQRKit

struct SafetyTests {
    private let inspector = CodeInspector(locale: Locale(identifier: "en_US"))

    @Test func IDNAndLookalikesAreCheckedAfterNormalization() {
        let unicode = inspector.inspect("https://csаs.cz.example.com")
        let encoded = inspector.inspect("https://xn--css-7cd.cz.example.com")
        for result in [unicode, encoded] {
            let ids = Set(result.assessment.findings.map(\.id))
            #expect(ids.contains("link.punycode"))
            #expect(ids.contains("link.mixedScripts"))
            #expect(ids.contains("link.impersonation"))
            #expect(result.assessment.floor >= 70)
        }
    }

    @Test func originalLinkIsRetainedAndBarePortsWork() {
        let original = " HTTPS://EXAMPLE.COM:443/path "
        let result = inspector.inspect(original)
        #expect(result.raw == original)
        #expect(result.content.facts.first { $0.id == "address" }?.value == "https://example.com/path")
        #expect(inspector.inspect("example.com:8443/path").content.kind == .link)
        #expect(inspector.inspect("https://example.com:999999999999999999999999").assessment.findings.contains { $0.id == "code.malformed" })
    }

    @Test func brandSubstringsDoNotFlagUnrelatedWords() {
        for address in ["https://templates.example.com", "https://monetary.example.org", "https://parking.example.com"] {
            #expect(!inspector.inspect(address).assessment.findings.contains { $0.id == "link.impersonation" })
        }
        #expect(inspector.inspect("https://airbank-login.example.com").assessment.findings.contains { $0.id == "link.impersonation" })
        #expect(!LinkRules.mixedScripts("δοκιμή.example"))
        #expect(LinkRules.mixedScripts("airbanك.example"))
    }

    @Test func tinyCryptoAmountsAreNotRoundedToZero() {
        let result = inspector.inspect("ethereum:0x0000000000000000000000000000000000000000?value=1")
        #expect(result.content.facts.first { $0.id == "amount" }?.value == "ETH 0.000000000000000001")
    }

    @Test func nestedInstructionsAndInspectionLimitsAreVisible() {
        let hidden = inspector.inspect("Invoice details:\nSPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example")
        #expect(hidden.content.kind == .text)
        #expect(hidden.assessment.findings.contains { $0.id == "content.combination" })
        let many = inspector.inspect((0..<40).map { "https://example.com/\($0)" }.joined(separator: " "))
        #expect(many.assessment.findings.contains { $0.id == "content.tooMany" })
        #expect(many.assessment.limitations.contains { $0.contains("32") })
        #expect(!many.benefitsFromCloudCheck)
    }

    @Test func squareHeaderLengthCannotOverflow() {
        #expect(PayBySquareParser.recognizes("000FVVV00000000000000000"))
    }

    @Test(arguments: ["javascript:alert(1)", "data:text/html,example", "file:///private/example", "tel:**21*+420777000000%23"])
    func unsafeCommandsHaveNoHandoff(_ raw: String) {
        let result = inspector.inspect(raw)
        #expect(result.assessment.level == .danger)
        #expect(result.actions.allSatisfy { $0.confirmation == nil })
    }

    @Test func harmlessInternationalAndReservedNumbersAreNotCalledPremium() {
        for raw in ["tel:+1900991234", "tel:907991234", "sms:95555?body=Hello", "tel:+421900991234"] {
            #expect(!inspector.inspect(raw).assessment.findings.contains { ["sms.premium", "phone.premium"].contains($0.id) })
        }
        #expect(PhoneRules.charge("00420905991234", sms: false)?.amount == 990)
        #expect(PhoneRules.charge("90301", sms: true)?.amount == nil)
        #expect(PhoneRules.charge("90301999", sms: true)?.amount == nil)
    }

    @Test func secretCodesDoNotExposeTheirSecretsInDisplayContent() {
        for raw in ["WIFI:T:WPA;S:Home;P:private-password;;", "LPA:1$rsp.example.com$private-activation", "otpauth://totp/Example?secret=JBSWY3DPEHPK3PXP"] {
            let result = inspector.inspect(raw)
            let display = result.content.facts.map(\.value).joined() + result.content.summary + result.assessment.consequences.joined()
            #expect(!display.contains("private-password"))
            #expect(!display.contains("private-activation"))
            #expect(!display.contains("JBSWY3DPEHPK3PXP"))
            #expect(result.containsSecrets)
            #expect(!result.benefitsFromCloudCheck)
        }
    }

    @Test func aSecretInsideAWebsiteIsNotEligibleForAutomaticCloudChecks() {
        let result = inspector.inspect("https://example.com/?setup=otpauth%3A%2F%2Ftotp%2FExample%3Fsecret%3DJBSWY3DPEHPK3PXP")
        #expect(result.content.kind == .link)
        #expect(result.containsSecrets)
        #expect(!result.benefitsFromCloudCheck)
        for address in ["https://user:example-password@example.com", "https://example.com/?access_token=example"] {
            #expect(!inspector.inspect(address).benefitsFromCloudCheck)
        }
    }

    @Test func oversizeInputDoesNotOfferAnActionOrClaimToHaveReadIt() {
        let result = inspector.inspect(String(repeating: "https://example.com ", count: 2_000))
        #expect(result.assessment.findings.map(\.id) == ["code.tooLarge"])
        #expect(result.content.facts.isEmpty)
        #expect(result.actions.allSatisfy { $0.confirmation == nil })
    }

    @Test func hostileInputsRemainBoundedAndDoNotCrash() {
        let prefixes = ["SPD*1.0*", "SID*1.0*", "BCD\n002\n", "SPC\n0200\n", "000201", "WIFI:", "BEGIN:VCARD\n", "BEGIN:VEVENT\n", "https://", "otpauth-migration://offline?data=", "bitcoin:", "LPA:", "SMSTO:", "geo:"]
        let alphabet = Array("aA0:;*%+\n\r\t?&#=\\🧪\u{202E}")
        var state: UInt64 = 42
        for prefix in prefixes {
            for size in [0, 1, 2, 4, 16, 64, 256] {
                var suffix = ""
                for _ in 0..<size {
                    state = state &* 6_364_136_223_846_793_005 &+ 1
                    suffix.append(alphabet[Int(state % UInt64(alphabet.count))])
                }
                let result = inspector.inspect(prefix + suffix)
                #expect((0...100).contains(result.assessment.score))
                #expect((0...result.assessment.score).contains(result.assessment.floor))
                #expect(Set(result.assessment.findings.map(\.id)).count == result.assessment.findings.count)
            }
        }
    }

    @Test func allSharedCasesRenderInBothLanguages() throws {
        for fixture in try CodeFixture.all {
            let english = inspector.inspect(fixture.raw)
            let czech = CodeInspector(locale: Locale(identifier: "cs_CZ")).inspect(fixture.raw)
            #expect(english.assessment.score == czech.assessment.score)
            #expect(english.assessment.findings.map(\.id) == czech.assessment.findings.map(\.id))
            #expect(!czech.content.summary.contains("%@"))
            #expect(!czech.content.title.isEmpty)
        }
        #expect(RiskLevel.caution.title(locale: Locale(identifier: "cs")) == "Buďte opatrní")
    }

    @Test func concurrentInspectorsUseTheSameImmutableResources() async {
        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<32 {
                group.addTask { inspector.inspect("SMSTO:9030199:START").assessment.score }
            }
            for await score in group { #expect(score == 85) }
        }
    }
}
