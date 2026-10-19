import Foundation

enum CalendarParser {
    static func parse(_ raw: String) -> ParsedCode {
        let properties = CardProperties.parse(raw)
        var event = CalendarEvent(iCalendar: raw.uppercased().hasPrefix("BEGIN:VCALENDAR") ? raw : "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n\(raw)\r\nEND:VCALENDAR")
        var issues: Set<DecodeIssue> = []
        var insideEvent = false
        var insideAlarm = false
        var counts: [String: Int] = [:]
        for property in properties {
            if property.name == "BEGIN", property.value.uppercased() == "VEVENT" { insideEvent = true }
            if property.name == "BEGIN", property.value.uppercased() == "VALARM" { insideAlarm = true }
            if property.name == "END", property.value.uppercased() == "VALARM" { insideAlarm = false; continue }
            if property.name == "END", property.value.uppercased() == "VEVENT" { insideEvent = false }
            guard insideEvent && !insideAlarm else { continue }
            counts[property.name, default: 0] += 1
            switch property.name {
            case "SUMMARY": event.title = ParseSupport.unescape(property.value)
            case "LOCATION": event.location = ParseSupport.unescape(property.value)
            case "DESCRIPTION": event.description = ParseSupport.unescape(property.value)
            case "URL": event.url = property.value
            case "DTSTART":
                event.isAllDay = property.value.count == 8
                event.timeZoneIdentifier = timeZone(property)
                event.start = date(property)
                if event.start == nil { issues.insert(.malformed) }
            case "DTEND":
                event.end = date(property)
                if event.end == nil { issues.insert(.malformed) }
            case "RRULE", "RDATE", "EXDATE", "ATTACH": issues.insert(.unsupported)
            default: break
            }
        }
        if properties.filter({ $0.name == "BEGIN" && $0.value.uppercased() == "VEVENT" }).count != 1
            || counts.contains(where: { ["SUMMARY", "DTSTART", "DTEND", "URL"].contains($0.key) && $0.value > 1 }) { issues.insert(.ambiguous) }
        if event.start == nil || !properties.contains(where: { $0.name == "END" && $0.value.uppercased() == "VEVENT" }) { issues.insert(.malformed) }
        if let start = event.start, let end = event.end, end < start { issues.insert(.malformed) }
        return ParsedCode(payload: .event(event), issues: issues)
    }

    private static func timeZone(_ property: CardProperties.Property) -> String? {
        if property.value.hasSuffix("Z") { return "UTC" }
        return property.parameters.components(separatedBy: ";").first { $0.hasPrefix("TZID=") }.map {
            String($0.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }

    private static func date(_ property: CardProperties.Property) -> Date? {
        let value = property.value
        guard ParseSupport.matches(value, #"^[0-9]{8}(?:T[0-9]{6}Z?)?$"#) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        if let identifier = timeZone(property) {
            guard let known = TimeZone.knownTimeZoneIdentifiers.first(where: { $0.uppercased() == identifier }) ?? (identifier == "UTC" ? "UTC" : nil),
                  let zone = TimeZone(identifier: known) else { return nil }
            formatter.timeZone = zone
        } else {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        }
        formatter.dateFormat = value.count == 8 ? "yyyyMMdd" : value.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        formatter.isLenient = false
        guard let result = formatter.date(from: value), formatter.string(from: result) == value else { return nil }
        return result
    }
}
