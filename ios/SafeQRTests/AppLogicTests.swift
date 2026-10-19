import Foundation
import Testing
import SafeQRKit
@testable import SafeQR

@Suite @MainActor
struct AppLogicTests {
    @Test func decodesCompletedContractAndPreservesDeviceFloor() async throws {
        let json = #"""
        {"id":"chk_abcdefghijklmnopqrst","status":"completed","steps":[
          {"id":"redirects","status":"done","label":"Redirects checked"},
          {"id":"scene","status":"skipped","label":"No photo"}],
          "result":{"score":12,"level":"safe","headline":"No new warning signs.",
            "findings":[{"id":"sandbox.review","severity":"info","title":"Reviewed","detail":"A page was inspected.","source":"sandbox"}],
            "consequences":["Your browser opens."],"limitations":["Ownership is unverified."],
            "link":{"finalUrl":"https://example.com/","hops":[{"url":"https://example.org/","via":"http","status":302},{"url":"https://example.com/","via":"javascript"}],"screenshotUrl":"https://api.safeqr.cz/screenshot","asksFor":["card"]},
            "scene":{"summary":"A parking machine.","matchesContent":true},
            "intel":[{"id":"case-1","title":"Reported sticker","summary":"A reported case.","sourceUrl":"https://example.org/report","publishedAt":"2026-10-19"}],
            "models":["model-id"]}}
        """#
        let check = try JSONDecoder().decode(CloudCheck.self, from: Data(json.utf8))
        let verdict = try #require(check.result)
        let local = try sample(score: 85, floor: 80).assessment
        let merged = local.merged(with: verdict.assessment)
        #expect(merged.score == 80)
        #expect(merged.findings.contains { $0.id == "device.proven" })
        #expect(verdict.link?.hops.count == 2)
        #expect(verdict.intel?.first?.publishedAt == "2026-10-19")
        #expect(check.steps.last?.status.value == .skipped)
        let model = ResultModel(analysis: try sample(score: 85, floor: 80), scene: nil)
        await model.run(using: CompletedCloud(verdict: verdict), consent: CheckConsent(links: true, surroundings: false))
        #expect(model.assessment.score == 80)
        #expect(model.headline == model.analysis.content.summary)
    }

    @Test func consentSeparatesPayloadAndPhotoAndBlocksSecrets() throws {
        let analysis = try sample()
        let photo = ScenePhoto(jpeg: Data([1, 2, 3]), source: .photo,
                               bounds: CodeBounds(rect: CGRect(x: 0.2, y: 0.1, width: 0.4, height: 0.3)))
        #expect(CheckConsent(links: false, surroundings: true).request(for: analysis, scene: photo) == nil)
        let withoutPhoto = try #require(CheckConsent(links: true, surroundings: false).request(for: analysis, scene: photo))
        #expect(withoutPhoto.scene == nil)
        let request = try #require(CheckConsent(links: true, surroundings: true).request(for: analysis, scene: photo))
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(object["kind"] as? String == "link")
        #expect((object["device"] as? [String: Any])?["floor"] as? Int == 40)
        #expect((object["scene"] as? [String: Any])?["source"] as? String == "photo")
        #expect((object["scene"] as? [String: Any])?["image"] as? String == "AQID")
        for raw in ["WIFI:T:WPA;S:Private;P:secret123;;", "otpauth://totp/me?secret=ABCD", "LPA:1$example.com$secret",
                    "https://wa.me/420777123456?text=Private%20message", "https://t.me/example?text=Private%20message"] {
            #expect(CheckConsent(links: true, surroundings: true).request(for: CodeInspector().inspect(raw), scene: photo) == nil)
        }
    }

    @Test func calendarHandoffPreservesAllDayDatesAndFloatingTimes() async throws {
        for (value, allDay) in [("20261025", true), ("20261025T120000", false)] {
            let analysis = CodeInspector().inspect("BEGIN:VEVENT\nSUMMARY:Meeting\nDTSTART:\(value)\nDESCRIPTION:Bring notes\nEND:VEVENT")
            let action = try #require(analysis.actions.first { $0.isHandoff })
            let handler = ActionHandler()
            await handler.perform(action, payload: analysis.content.payload)
            guard case .event(let event, _) = handler.presentation else {
                Issue.record("Expected a calendar editor")
                continue
            }
            let calendar = Calendar(identifier: .gregorian)
            let start = try #require(event.startDate)
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: start)
            #expect(parts == DateComponents(year: 2026, month: 10, day: 25, hour: allDay ? 0 : 12))
            #expect(event.isAllDay == allDay)
            #expect(event.notes == "Bring notes")
            #expect(event.timeZone == nil)
            let expectedEnd = allDay ? calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) : start
            #expect(event.endDate == expectedEnd)
        }
    }

    @Test func calendarHandoffPreservesAnExplicitTimeZone() async throws {
        let analysis = CodeInspector().inspect("BEGIN:VEVENT\nDTSTART;TZID=Europe/Prague:20261020T120000\nDTEND;TZID=Europe/Prague:20261020T130000\nEND:VEVENT")
        let handler = ActionHandler()
        await handler.perform(try #require(analysis.actions.first { $0.isHandoff }), payload: analysis.content.payload)
        guard case .event(let event, _) = handler.presentation else {
            Issue.record("Expected a calendar editor")
            return
        }
        #expect(event.startDate?.ISO8601Format() == "2026-10-20T10:00:00Z")
        #expect(event.endDate?.ISO8601Format() == "2026-10-20T11:00:00Z")
        #expect(event.timeZone?.identifier == "Europe/Prague")
    }

    @Test func allDayCalendarEndIsExclusive() async throws {
        let analysis = CodeInspector().inspect("BEGIN:VEVENT\nDTSTART;VALUE=DATE:20261024\nDTEND;VALUE=DATE:20261026\nEND:VEVENT")
        let handler = ActionHandler()
        await handler.perform(try #require(analysis.actions.first { $0.isHandoff }), payload: analysis.content.payload)
        guard case .event(let event, _) = handler.presentation else {
            Issue.record("Expected a calendar editor")
            return
        }
        let end = try #require(event.endDate)
        let components = Calendar(identifier: .gregorian).dateComponents([.day, .hour, .minute, .second], from: end)
        #expect(components == DateComponents(day: 25, hour: 23, minute: 59, second: 59))
    }

    @Test func failedCloudLeavesDeviceResultUsable() async throws {
        let model = ResultModel(analysis: try sample(), scene: nil)
        await model.run(using: FailingCloud(), consent: CheckConsent(links: true, surroundings: false))
        #expect(model.assessment.score == 60)
        #expect(model.cloudLimitation != nil)
        #expect(model.verdict == nil)
        #expect(!model.checking)
    }

    @Test func historyRequiresOptInAndCanBeDeleted() throws {
        let history = try HistoryStore(inMemory: true)
        let analysis = try sample()
        history.record(analysis, assessment: analysis.assessment, enabled: false)
        #expect(history.records.isEmpty)
        history.record(analysis, assessment: analysis.assessment, enabled: true)
        #expect(history.records.count == 1)
        let raised = analysis.assessment.merged(with: RemoteAssessment(score: 90, findings: [], consequences: [], limitations: []))
        history.record(analysis, assessment: raised, enabled: true)
        #expect(history.records.count == 1)
        #expect(history.records.first?.score == 90)
        history.delete(try #require(history.records.first))
        #expect(history.records.isEmpty)
        history.record(analysis, assessment: analysis.assessment, enabled: true)
        history.clear()
        #expect(history.records.isEmpty)
    }

    @Test func consentDefaultsToOffAndPersistsChoices() throws {
        let suite = "cz.safeqr.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        #expect(!preferences.historyEnabled)
        #expect(!preferences.consent.links)
        preferences.deepChecksEnabled = true
        preferences.sceneChecksEnabled = true
        let reopened = AppPreferences(defaults: defaults)
        #expect(reopened.consent == CheckConsent(links: true, surroundings: true))
        reopened.deepChecksEnabled = false
        #expect(!reopened.consent.surroundings)
    }

    @Test func actionURLsDoNotTurnRecipientsIntoInjectedQueries() throws {
        #expect(HandoffURLBuilder.url(for: .call(phoneNumber: "123?body=bad")) == nil)
        #expect(HandoffURLBuilder.url(for: .open(try #require(URL(string: "javascript:alert(1)")))) == nil)
        let url = try #require(HandoffURLBuilder.url(for: .sendSMS(recipient: "+420 777 123 456", body: "a&b?c#d")))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "+420777123456")
        #expect(components.queryItems == [URLQueryItem(name: "body", value: "a&b?c#d")])
        let action = CodeAction(id: "handoff", kind: .open(try #require(URL(string: "https://example.com"))), title: "Open", confirmation: nil)
        #expect(action.isHandoff)
        #expect(!action.requiredConfirmation.message.isEmpty)
    }

    @Test func guideResourcesContainAllRecoveryScenariosAndScopedBankLines() {
        let library = GuideLibrary()
        #expect(!library.loadFailed)
        #expect(library.guides.filter { $0.category == "recovery" }.count == 8)
        #expect(library.banks.contains { $0.bank == "Fio banka" && $0.phone == "+420 224 346 392" })
        #expect(library.guides.allSatisfy { !$0.title.cs.isEmpty && !$0.title.en.isEmpty })
        #expect(library.banks.allSatisfy { !$0.scope.cs.isEmpty && !$0.hours.cs.isEmpty })
    }

    private func sample(score: Int = 60, floor: Int = 40) throws -> CodeAnalysis {
        let url = try #require(URL(string: "https://example.com"))
        return CodeAnalysis(raw: url.absoluteString, symbology: .qr,
                            content: CodeContent(kind: .link, payload: .link(url), title: "Link", summary: "A website.", facts: []),
                            assessment: RiskAssessment(score: score, floor: floor,
                                                       findings: [Finding(id: "device.proven", severity: .danger, title: "Warning", detail: "A device finding.")],
                                                       consequences: [], limitations: []),
                            actions: [CodeAction(id: "open", kind: .open(url), title: "Open", confirmation: nil)])
    }
}

private struct FailingCloud: CloudChecking {
    func check(_ request: CheckRequest, onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        throw CloudError.unavailable
    }
}

private struct CompletedCloud: CloudChecking {
    let verdict: CloudVerdict
    func check(_ request: CheckRequest, onProgress: @escaping @MainActor @Sendable ([CheckStep]) -> Void) async throws -> CloudVerdict {
        verdict
    }
}
