import Foundation
import Testing
import SafeQRKit
@testable import SafeQR

struct CloudContractTests {
    @Test func invalidEndpointNeverStartsAnUpload() async {
        let request = CheckRequest(analysis: CodeInspector().inspect("https://example.com"), scene: nil)
        for endpoint in [nil, URL(string: "http://example.com"), URL(string: "https://user:secret@example.com"), URL(string: "https://example.com?redirect=other")] {
            await #expect(throws: CloudError.invalidResponse) {
                try await CloudClient(baseURL: endpoint).check({ request }) { _ in }
            }
        }
    }

    @Test func decodesAcceptedRunningAndFailedChecks() throws {
        let accepted = try decode(CheckAccepted.self, #"{"id":"chk_abcdefghijklmnopqrst","status":"running","pollAfterMs":2000}"#)
        #expect(accepted.status.value == .running)
        #expect(accepted.pollAfterMs == 2000)
        let running = try decode(CloudCheck.self, #"{"id":"chk_abcdefghijklmnopqrst","status":"running","steps":[{"id":"sandbox","status":"running","label":"Checking the website"}]}"#)
        #expect(running.result == nil)
        #expect(running.pollAfterMs == nil)
        #expect(running.steps.first?.status.value == .running)
        let failed = try decode(CloudCheck.self, #"{"id":"chk_abcdefghijklmnopqrst","status":"failed","steps":[{"id":"verdict","status":"failed","label":"The check could not finish"}]}"#)
        #expect(failed.status.value == .failed)
        #expect(failed.result == nil)
        #expect(failed.steps.first?.status.value == .failed)
    }

    @Test func optionalEvidenceCanBeAbsentOrMinimal() throws {
        let minimal = try verdict()
        #expect(minimal.isValid)
        #expect(minimal.link == nil && minimal.scene == nil && minimal.intel == nil)
        let evidence = try decode(CloudVerdict.self, #"""
        {"score":45,"level":"caution","headline":"Check the destination.","findings":[],
         "consequences":[],"limitations":[],"models":[],
         "link":{"finalUrl":"https://example.com","hops":[{"url":"https://example.com","via":"http"}]},
         "scene":{"summary":"No clear surroundings."},"intel":[]}
        """#)
        #expect(evidence.isValid)
        #expect(evidence.link?.hops.first?.status == nil)
        #expect(evidence.link?.screenshotUrl == nil)
        #expect(evidence.scene?.matchesContent == nil)
        #expect(evidence.intel?.isEmpty == true)
    }

    @Test func unknownEnumsDecodeWithoutBecomingKnownSafetyClaims() throws {
        let future = try decode(CloudCheck.self, #"""
        {"id":"chk_abcdefghijklmnopqrst","status":"queued",
         "steps":[{"id":"future-agent","status":"retrying","label":"Trying again"}],
         "result":{"score":45,"level":"elevated","headline":"Review this code.",
           "findings":[{"id":"new.rule","severity":"critical","title":"Review","detail":"New evidence","source":"future-agent"}],
           "consequences":[],"limitations":[],"models":[],
           "link":{"finalUrl":"https://example.com","hops":[{"url":"https://example.com","via":"future-redirect"}],"asksFor":["future-permission"]}}}
        """#)
        #expect(future.status.value == nil)
        #expect(future.steps.first?.status.value == nil)
        #expect(future.steps.first?.id == "future-agent")
        let result = try #require(future.result)
        #expect(!result.isValid)
        #expect(result.level.value == nil)
        #expect(result.findings.first?.finding == nil)
        #expect(result.link?.hops.first?.via == "future-redirect")
        #expect(result.link?.asksFor == ["future-permission"])
    }

    @Test(arguments: [(-1, "safe"), (101, "danger"), (80, "safe"), (45, "future")])
    func rejectsInvalidOrInconsistentRisk(score: Int, level: String) throws {
        #expect(try !verdict(score: score, level: level).isValid)
    }

    private func verdict(score: Int = 45, level: String = "caution") throws -> CloudVerdict {
        try decode(CloudVerdict.self, """
        {"score":\(score),"level":"\(level)","headline":"Check the destination.","findings":[],
         "consequences":[],"limitations":[],"models":[]}
        """)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
