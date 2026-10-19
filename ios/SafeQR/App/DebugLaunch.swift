#if DEBUG
import Foundation

enum DebugLaunch {
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--screen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

enum DebugSample: String, CaseIterable, Identifiable {
    case link, payment, wifi, premiumSMS
    var id: String { rawValue }
    var title: String {
        switch self {
        case .link: L10n.text("Link")
        case .payment: L10n.text("Payment")
        case .wifi: L10n.text("Wi-Fi")
        case .premiumSMS: L10n.text("Premium SMS")
        }
    }
    var raw: String {
        switch self {
        case .link: "https://www.praha.eu"
        case .payment: "SPD*1.0*ACC:CZ6508000000192000145399*AM:250.00*CC:CZK*MSG:Parkovani*X-VS:123456"
        case .wifi: "WIFI:T:nopass;S:Free Public WiFi;;"
        case .premiumSMS: "SMSTO:9009901:ANO"
        }
    }
}
#endif
