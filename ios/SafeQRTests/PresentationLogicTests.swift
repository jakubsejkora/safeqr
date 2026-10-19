import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

struct PresentationLogicTests {
    @Test func riskMeterKeepsExtremeScoresInsideTheTrack() {
        #expect(RiskMeterScale.position(-10, width: 300) == 5)
        #expect(RiskMeterScale.position(0, width: 300) == 5)
        #expect(RiskMeterScale.position(50, width: 300) == 150)
        #expect(RiskMeterScale.position(100, width: 300) == 295)
        #expect(RiskMeterScale.position(999, width: 300) == 295)
        #expect(RiskMeterScale.position(70, width: 0) == 0)
        #expect(RiskMeterScale.fraction(30) == 0.3)
        #expect(RiskMeterScale.fraction(70) == 0.7)
    }

    @Test func addressHighlightsTheOwnerRatherThanAnImpersonatingSubdomain() throws {
        let url = try #require(URL(string: "https://bank.example.co.uk/pay?token=private"))
        let parts = AddressParts(url: url)
        #expect(parts.prefix == "bank.")
        #expect(parts.domain == "example.co.uk")
        #expect(parts.suffix == "/pay?…")
        #expect(!parts.unencrypted)
        let lookalike = AddressParts(url: try #require(URL(string: "http://xn--pple-43d.test/path")))
        #expect(lookalike.unencrypted)
        #expect(!lookalike.suspiciousLabels.isEmpty)
        let ipv4 = AddressParts(url: try #require(URL(string: "https://192.0.2.1/")))
        #expect(ipv4.domain == "192.0.2.1")
        let hosted = AddressParts(url: try #require(URL(string: "https://bank.evil.workers.dev")))
        #expect(hosted.domain == "evil.workers.dev")
        let international = AddressParts(url: try #require(URL(string: "https://www.食狮.公司.cn")))
        #expect(international.prefix == "www.")
        #expect(international.domain == "xn--85x722f.xn--55qx5d.cn")
        let repeated = AddressParts(url: try #require(URL(string: "https://example.com.evil.example.com/pay")))
        #expect(repeated.prefix == "example.com.evil.")
        #expect(repeated.domain == "example.com")
        let installation = AddressParts(url: try #require(URL(string: "itms-services://?action=download-manifest")))
        #expect(installation.domain == "itms-services")
        #expect(installation.suffix == ":?…")
    }

    @Test func suffixRulesRespectWildcardAndExceptionBoundaries() {
        let rules = PublicSuffixRules(text: "com\nco.uk\n*.ck\n!www.ck")
        #expect(rules.registrableDomain("bank.example.co.uk") == "example.co.uk")
        #expect(rules.registrableDomain("a.b.ck") == "a.b.ck")
        #expect(rules.registrableDomain("a.www.ck") == "www.ck")
    }

    @Test func portraitAspectFillMapsTheRotatedCaptureWithoutASecondRotation() {
        let code = CodeBounds(rect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        let portrait = PreviewGeometry.rect(code, frame: CGSize(width: 1080, height: 1920), viewport: CGSize(width: 360, height: 640))
        #expect(portrait == CGRect(x: 90, y: 160, width: 180, height: 320))
        let cropped = PreviewGeometry.rect(code, frame: CGSize(width: 1280, height: 960), viewport: CGSize(width: 360, height: 640))
        #expect(abs(cropped.midX - 180) < 0.001)
        #expect(abs(cropped.width - 426.6666667) < 0.001)
        #expect(cropped.minY == 160)
        #expect(PreviewGeometry.rect(code, frame: .zero, viewport: CGSize(width: 360, height: 640)) == .zero)
    }

    @Test func nearbyCodePillsRemainSeparateAndInsideThePreview() {
        let rectangles = [CGRect(x: 20, y: 350, width: 80, height: 80), CGRect(x: 150, y: 350, width: 80, height: 80),
                          CGRect(x: 270, y: 350, width: 80, height: 80)]
        let points = ScannerPillLayout.centers(for: rectangles, viewport: CGSize(width: 390, height: 844))
        #expect(points.count == 3)
        #expect(abs(points[0].y - points[1].y) >= 80)
        #expect(abs(points[1].y - points[2].y) >= 80)
        #expect(abs(points[0].y - points[2].y) >= 80)
        #expect(points.allSatisfy { $0.x >= 186 && $0.x <= 204 && $0.y >= 150 && $0.y <= 694 })
    }

    @Test func releasingTheDangerHoldClearsProgress() {
        var hold = HoldProgress()
        hold.update(elapsed: 1.4)
        #expect(hold.fraction < 1)
        hold.cancel()
        #expect(hold.fraction == 0)
        hold.update(elapsed: 1.5)
        #expect(hold.fraction == 1)
    }

    @Test func anUnselectedPrivateCodeAlsoKeepsTheSceneOnDevice() {
        let bounds = CodeBounds(rect: CGRect(x: 0, y: 0, width: 0.2, height: 0.2))
        let link = ScannedCode(raw: "https://example.com", symbology: .qr, bounds: bounds)
        let secret = ScannedCode(raw: "WIFI:T:WPA;S:Home;P:private-password;;", symbology: .qr, bounds: bounds)
        #expect(!ScenePrivacy.containsSecrets([link]))
        #expect(ScenePrivacy.containsSecrets([link, secret]))
    }

    @Test func hiddenEmailRecipientIsVisibleAndAuthenticationSecretsStayHidden() {
        let inspector = CodeInspector(locale: Locale(identifier: "en"))
        let email = inspector.inspect("mailto:person@example.com?bcc=other@example.org")
        #expect(email.content.facts.contains { $0.id == "hiddenRecipient" && $0.emphasis == .warning && $0.value == "other@example.org" })
        let repeated = inspector.inspect("mailto:person@example.com?BCC=first@example.org&bcc=second@example.org")
        #expect(Set(repeated.content.facts.map(\.id)).count == repeated.content.facts.count)
        #expect(repeated.content.facts.first { $0.id == "hiddenRecipient" }?.value == "first@example.org, second@example.org")
        let login = inspector.inspect("otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP")
        #expect(!login.content.facts.contains { $0.value.contains("JBSWY3DPEHPK3PXP") })
        #expect(CheckConsent(links: true, surroundings: true).request(for: login, scene: nil) == nil)
    }
}
