import Foundation
import Testing
@testable import SafeQRKit

struct StructuredParserTests {
    @Test func wifiEscapesDoNotCreateFields() throws {
        let parsed = WiFiParser.parse(#"WIFI:T:WPA;S:Cafe\;S\:other;P:a\;b\:c\\d;H:true;;"#)
        guard case .wifi(let network) = parsed.payload else { throw TestError.wrongKind }
        #expect(network.ssid == "Cafe;S:other")
        #expect(network.password == #"a;b:c\d"#)
        #expect(network.isHidden)
        #expect(parsed.issues.isEmpty)
    }

    @Test func foldedVCardAndQuotedPrintable() throws {
        let raw = "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Novák;Jan;;;\r\nFN:Jan\r\n Novák\r\nitem1.TEL;TYPE=CELL:+420777000000\r\nNOTE;ENCODING=QUOTED-PRINTABLE:P=C5=99=C3=AD=\r\nli=C5=A1\r\nEND:VCARD"
        guard case .contact(let card) = ContactParser.parse(raw).payload else { throw TestError.wrongKind }
        #expect(card.name == "JanNovák")
        #expect(card.note == "Příliš")
        #expect(card.phoneNumbers == ["+420777000000"])
    }

    @Test func calendarTimeZoneAndAlarmAreSeparate() throws {
        let raw = "BEGIN:VEVENT\nSUMMARY:Meeting\nDTSTART;TZID=Europe/Prague:20261020T120000\nBEGIN:VALARM\nDESCRIPTION:Alarm\nEND:VALARM\nDESCRIPTION:Event\nEND:VEVENT"
        let parsed = CalendarParser.parse(raw)
        guard case .event(let event) = parsed.payload else { throw TestError.wrongKind }
        #expect(event.description == "Event")
        #expect(event.start?.ISO8601Format() == "2026-10-20T10:00:00Z")
        #expect(parsed.issues.isEmpty)
    }

    @Test func unsupportedCalendarDurationCannotBecomeADifferentEvent() {
        let result = CodeInspector().inspect("BEGIN:VEVENT\nDTSTART:20261020T120000Z\nDURATION:PT2H\nEND:VEVENT")
        #expect(result.assessment.findings.contains { $0.id == "code.unsupported" })
        #expect(result.actions.allSatisfy { $0.confirmation == nil })
    }

    @Test(arguments: ["geo:,50,14", "geo:50,,14", "geo:50,14,"])
    func missingCoordinatesDoNotShiftTheDestination(_ raw: String) {
        let result = CodeInspector().inspect(raw)
        #expect(result.assessment.findings.contains { $0.id == "code.malformed" })
        #expect(result.actions.allSatisfy { $0.confirmation == nil })
    }

    @Test func emailHeadersAreCaseInsensitive() throws {
        let parsed = EmailParser.parse("mailto:person@example.com?SUBJECT=Hello&BODY=Message")
        guard case .email(_, let subject, let body) = parsed.payload else { throw TestError.wrongKind }
        #expect(subject == "Hello")
        #expect(body == "Message")
        #expect(parsed.issues.isEmpty)
        for query in ["BCC=other@example.com", "CC=other@example.com", "TO=other@example.com", "subject=One&SUBJECT=Two"] {
            #expect(EmailParser.parse("mailto:person@example.com?" + query).issues.contains(.ambiguous))
        }
    }

    @Test func authenticatorExportCountsAccountsWithoutDisplayingSecrets() throws {
        let account: [UInt8] = [10, 3, 1, 2, 3, 18, 1, 65]
        let data = Data([10, UInt8(account.count)] + account + [10, UInt8(account.count)] + account + [16, 1, 24, 2])
        var components = URLComponents(string: "otpauth-migration://offline")!
        components.queryItems = [URLQueryItem(name: "data", value: data.base64EncodedString())]
        let result = CodeInspector(locale: Locale(identifier: "en")).inspect(components.string!)
        guard case .login(let login) = result.content.payload else { throw TestError.wrongKind }
        #expect(login.accountCount == 2)
        #expect(login.batchSize == 2)
        #expect(result.assessment.floor == 85)
        #expect(!result.content.facts.contains { $0.value.contains(data.base64EncodedString()) })
    }

    @Test func malformedProtobufIsRejected() {
        #expect(AuthenticatorExportParser.decode([10, 255, 255]) == nil)
        #expect(AuthenticatorExportParser.decode(Array(repeating: 255, count: 12)) == nil)
    }

    @Test func phoneContextAndExtensionCannotHideAServiceCommand() throws {
        let parsed = PhoneParser.parse("tel:900991234;phone-context=+420;ext=123")
        guard case .phone(let number) = parsed.payload else { throw TestError.wrongKind }
        #expect(number == "+420900991234;ext=123")
        #expect(parsed.issues.isEmpty)
        #expect(PhoneParser.parse("tel:+420777000000;ext=**21*123%23").issues.contains(.malformed))
    }

    @Test func ethereumUsesWeiAndTokenBaseUnits() throws {
        let address = "0x0000000000000000000000000000000000000000"
        guard case .crypto(let native) = CryptoParser.parse("ethereum:\(address)@1?value=1e18")?.payload,
              case .crypto(let token) = CryptoParser.parse("ethereum:\(address)@1/transfer?address=\(address)&uint256=1000000")?.payload else { throw TestError.wrongKind }
        #expect(native.amount == 1)
        #expect(native.amountUnit == "ETH")
        #expect(token.amount == 1_000_000)
        #expect(token.amountUnit == "baseUnits")
    }
}
