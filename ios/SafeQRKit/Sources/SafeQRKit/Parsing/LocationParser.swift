import Foundation

enum LocationParser {
    static func parse(_ raw: String) -> ParsedCode {
        let query = ParseSupport.query(raw)
        let content = ParseSupport.body(raw).split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let coordinates = content.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)[0].split(separator: ",")
        guard (2...3).contains(coordinates.count), let latitude = Double(coordinates[0]), let longitude = Double(coordinates[1]),
              latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            return ParsedCode(payload: .text(raw), issues: [.malformed])
        }
        var issues: Set<DecodeIssue> = query.duplicate ? [.ambiguous] : []
        if coordinates.count == 3, Double(coordinates[2])?.isFinite != true { issues.insert(.malformed) }
        for parameter in content.split(separator: ";").dropFirst() {
            let pair = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if pair.count == 2 && pair[0].lowercased() == "crs" && pair[1].lowercased() != "wgs84" { issues.insert(.unsupported) }
            if pair.count == 2 && pair[0].lowercased() == "u", (Double(pair[1]) ?? -1) < 0 { issues.insert(.malformed) }
        }
        return ParsedCode(payload: .location(latitude: latitude, longitude: longitude, query: query.fields["q"]), issues: issues)
    }
}
