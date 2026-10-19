import Foundation

enum WiFiParser {
    static func parse(_ raw: String) -> ParsedCode {
        let map = ParseSupport.fieldMap(ParseSupport.escapedFields(ParseSupport.body(raw)))
        let fields = map.fields
        let type = (fields["T"] ?? "nopass").uppercased()
        let security: WiFiSecurity = type == "WEP" ? .wep : ["", "NOPASS", "OPEN"].contains(type) ? .open : .wpa
        var network = WiFiNetwork(ssid: fields["S"] ?? "", password: fields["P"], security: security,
                                  isHidden: ["TRUE", "1"].contains(fields["H"]?.uppercased() ?? ""))
        network.authenticationType = type
        var issues: Set<DecodeIssue> = map.duplicate ? [.ambiguous] : []
        if network.ssid.isEmpty || network.ssid.utf8.count > 32 { issues.insert(.malformed) }
        if !["", "NOPASS", "OPEN", "WEP", "WPA", "WPA2", "WPA3", "SAE"].contains(type)
            || fields["E"] != nil || fields["I"] != nil || fields["PH2"] != nil { issues.insert(.unsupported) }
        if security != .open && network.password?.isEmpty != false { issues.insert(.malformed) }
        return ParsedCode(payload: .wifi(network), issues: issues)
    }
}
