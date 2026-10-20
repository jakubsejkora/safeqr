import Foundation
import SafeQRKit
import Testing
@testable import SafeQR

@Suite @MainActor
struct SecureLinkUpgradeTests {
    struct Route: Sendable {
        let original: String
        let hops: [String]
        let expected: String?
    }

    @Test(arguments: [
        Route(original: "http://www.vodafone.cz", hops: ["http://www.vodafone.cz/", "https://www.vodafone.cz/"],
              expected: "https://www.vodafone.cz/"),
        Route(original: "http://vodafone.cz", hops: ["http://vodafone.cz/", "https://www.vodafone.cz/"],
              expected: "https://www.vodafone.cz/"),
        Route(original: "http://www.parkujvklidu.cz", hops: ["http://www.parkujvklidu.cz/", "https://parking.praha.eu/parking"],
              expected: nil),
        Route(original: "http://vodafone.cz", hops: ["http://vodafone.cz/", "https://www.vodafone.cz/first", "https://example.org/final"],
              expected: "https://www.vodafone.cz/first"),
        Route(original: "http://vodafone.cz", hops: ["http://vodafone.cz/", "http://www.vodafone.cz/"],
              expected: nil),
        Route(original: "http://first.github.io", hops: ["http://first.github.io/", "https://second.github.io/"],
              expected: nil),
        Route(original: "https://vodafone.cz", hops: ["https://vodafone.cz/", "https://www.vodafone.cz/"],
              expected: nil),
        Route(original: "http://vodafone.cz", hops: ["http://vodafone.cz/", "https://example.org/", "https://www.vodafone.cz/"],
              expected: nil),
        Route(original: "http://vodafone.cz", hops: ["http://vodafone.cz/", "https://user:password@www.vodafone.cz/"],
              expected: nil),
        Route(original: "http://vodafone.cz", hops: ["https://www.vodafone.cz/"],
              expected: nil)
    ])
    func upgradesOnlyAnObservedRedirectOnTheOriginalDomain(_ route: Route) async throws {
        let model = ResultModel(analysis: CodeInspector().inspect(route.original), scene: nil)
        let report = report(route.hops)
        let client = UpgradeCheck(verdict: verdict(report))
        model.start(using: client, consent: enabled)
        #expect(model.secureURL == nil)
        #expect(!model.allowsHandoff)
        await model.run(using: client, consent: enabled)
        #expect(model.secureURL?.absoluteString == route.expected)
        let action = try #require(model.actions.first { $0.isHandoff })
        #expect(HandoffURLBuilder.url(for: action.kind)?.absoluteString == (route.expected ?? route.original))
    }

    @Test(arguments: ["disabled", "failed", "missingLink"])
    func incompleteEvidencePreservesTheOriginalAction(_ state: String) async throws {
        let original = "http://www.vodafone.cz"
        let model = ResultModel(analysis: CodeInspector().inspect(original), scene: nil)
        #expect(model.secureURL == nil)
        let client = UpgradeCheck(verdict: state == "failed" ? nil : verdict(state == "missingLink" ? nil :
            report([original, "https://www.vodafone.cz/"])))
        await model.run(using: client, consent: state == "disabled" ? CheckConsent(links: false, surroundings: false) : enabled)
        #expect(model.secureURL == nil)
        #expect(model.actions == model.analysis.actions)
        #expect(model.actions.first?.requiredConfirmation.isRisky == true)
    }

    @Test func confirmationUsesTheExactUpgradeWhileCopyAndShareKeepTheCode() async throws {
        let original = "http://vodafone.cz/poster?campaign=prague"
        let destination = "https://www.vodafone.cz/offers?campaign=prague"
        let model = ResultModel(analysis: CodeInspector().inspect(original), scene: nil)
        await model.run(using: UpgradeCheck(verdict: verdict(report([original, destination]))), consent: enabled)
        let action = try #require(model.actions.first { $0.isHandoff })
        let expectedURL = try #require(URL(string: destination))
        #expect(action.kind == .open(expectedURL))
        #expect(action.requiredConfirmation.message.contains(destination))
        #expect(!action.requiredConfirmation.message.contains(original))
        #expect(model.actions.first { $0.id == "copy" }?.kind == .copy(original))
        #expect(model.actions.first { $0.id == "share" }?.kind == .share(original))
        #expect(model.confirmationReason == nil)
    }

    @Test func aFinalURLAloneAndUnknownTransitionsAreNotRedirectEvidence() throws {
        let original = try #require(URL(string: "http://vodafone.cz"))
        let destination = "https://www.vodafone.cz/"
        #expect(SecureLinkUpgrade.destination(for: original, hops: []) == nil)
        for via in ["unknown", "http"] {
            let hops = [LinkReport.Hop(url: original.absoluteString, status: 200, via: "http"),
                        LinkReport.Hop(url: destination, status: 200, via: via)]
            #expect(SecureLinkUpgrade.destination(for: original, hops: hops) == nil)
        }
    }

    private let enabled = CheckConsent(links: true, surroundings: false)

    private func report(_ urls: [String]) -> LinkReport {
        LinkReport(finalUrl: urls.last ?? "", hops: urls.enumerated().map { index, url in
            LinkReport.Hop(url: url, status: index == urls.count - 1 ? 200 : 301, via: "http")
        }, pageTitle: nil, screenshotUrl: nil, domainAgeDays: nil, asksFor: nil)
    }

    private func verdict(_ link: LinkReport?) -> CloudVerdict {
        CloudVerdict(score: 5, level: .known(.safe), headline: "Checked.", findings: [], consequences: [],
                     limitations: [], link: link, scene: nil, intel: nil, models: [])
    }
}

private struct UpgradeCheck: CloudChecking {
    let verdict: CloudVerdict?

    func check(_ makeRequest: @escaping CheckRequestProvider,
               onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        guard await makeRequest() != nil, let verdict else { throw CloudError.unavailable }
        return verdict
    }
}
