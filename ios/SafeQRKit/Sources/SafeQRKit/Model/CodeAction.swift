import Foundation

/// Something the person can do with a code. Every hand-off to another app needs an explicit confirmation.
public struct CodeAction: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case open(URL)
        case call(phoneNumber: String)
        case sendSMS(recipient: String, body: String?)
        case composeEmail(recipient: String, subject: String?, body: String?)
        case joinWiFi(ssid: String, password: String?, security: WiFiSecurity)
        case addContact(vCard: String)
        case addEvent(iCalendar: String)
        /// Shares a newly encoded QR Platba image after confirmation.
        case sharePayment(PaymentRequest)
        case copy(String)
        case share(String)
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let isPrimary: Bool
    /// Required for hand-offs; copying and sharing do not need a separate confirmation.
    public let confirmation: Confirmation?

    public var isRisky: Bool { confirmation?.isRisky ?? false }

    public init(id: String, kind: Kind, title: String, isPrimary: Bool = false, confirmation: Confirmation?) {
        self.id = id
        self.kind = kind
        self.title = title
        self.isPrimary = isPrimary
        self.confirmation = confirmation
    }
}

public struct Confirmation: Sendable, Hashable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    /// Marks a risky hand-off so the interface can make it visually harder to confirm.
    public let isRisky: Bool

    public init(title: String, message: String, confirmTitle: String, isRisky: Bool) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isRisky = isRisky
    }
}

public enum WiFiSecurity: String, Sendable, Codable {
    case open, wep, wpa
}
