import Foundation

/// The decoded meaning of a code.
public enum Payload: Sendable, Hashable {
    case link(URL)
    case payment(PaymentRequest)
    case crypto(CryptoRequest)
    case sms(recipient: String, body: String?)
    case phone(number: String)
    case email(recipient: String, subject: String?, body: String?)
    case wifi(WiFiNetwork)
    case contact(ContactCard)
    case event(CalendarEvent)
    case location(latitude: Double, longitude: Double, query: String?)
    case messaging(MessagingLink)
    case login(LoginCode)
    case eSIM(ESIMActivation)
    case appLink(URL)
    case text(String)
}

public struct PaymentRequest: Sendable, Hashable {
    public enum Format: String, Sendable, Codable {
        /// Czech "QR Platba" (`SPD*1.0*…`).
        case czechSPD
        /// Czech "QR Faktura" (`SID*1.0*…`).
        case czechInvoice
        /// European Payments Council SEPA credit transfer (`BCD…`).
        case sepaEPC
        /// Slovak PAY by square.
        case payBySquare
        case swissQRBill
        case emvMerchant
        case upi
    }

    public var format: Format
    public var iban: String?
    public var bic: String?
    public var bankCode: String?
    public var recipientName: String?
    public var amount: Decimal?
    public var currency: String?
    public var message: String?
    public var variableSymbol: String?
    public var constantSymbol: String?
    public var specificSymbol: String?
    public var dueDate: DateComponents?
    public var isInstant: Bool?
    public var alternateAccounts: [String] = []
    public var domesticAccount: String?
    public var bankName: String?
    public var reference: String?
    public var paymentID: String?
    public var paymentURL: String?
    public var notificationType: String?
    public var notificationAddress: String?
    public var retryDays: Int?
    public var isSelfPayment: Bool?
    public var payeeIdentifier: String?
    public var checksum: ChecksumStatus = .notPresent
    /// Decoded fields, including extensions the current engine does not interpret.
    public var fields: [String: String] = [:]

    public init(format: Format) {
        self.format = format
    }
}

public struct CryptoRequest: Sendable, Hashable {
    public enum Network: String, Sendable, Codable {
        case bitcoin, lightning, ethereum, solana, litecoin, tron, other
    }

    public var network: Network
    public var address: String
    public var amount: Decimal?
    public var assetContract: String?
    public var label: String?
    public var message: String?
    /// The unit of `amount`; token base units are never presented as whole tokens.
    public var amountUnit: String?
    public var chainID: String?
    public var function: String?
    public var checksum: ChecksumStatus = .notPresent
    public var parameters: [String: String] = [:]

    public init(network: Network, address: String) {
        self.network = network
        self.address = address
    }
}

public struct WiFiNetwork: Sendable, Hashable {
    public var ssid: String
    public var password: String?
    public var security: WiFiSecurity
    public var isHidden: Bool
    public var authenticationType: String?

    public init(ssid: String, password: String?, security: WiFiSecurity, isHidden: Bool) {
        self.ssid = ssid
        self.password = password
        self.security = security
        self.isHidden = isHidden
    }
}

public struct ContactCard: Sendable, Hashable {
    public var name: String?
    public var organization: String?
    public var phoneNumbers: [String]
    public var emails: [String]
    public var urls: [String]
    public var note: String?
    /// The card normalised to vCard for hand-off to Contacts.
    public var vCard: String

    public init(vCard: String) {
        self.vCard = vCard
        phoneNumbers = []
        emails = []
        urls = []
    }
}

public struct CalendarEvent: Sendable, Hashable {
    public var title: String?
    public var start: Date?
    public var end: Date?
    public var location: String?
    public var iCalendar: String
    public var description: String?
    public var url: String?
    public var isAllDay: Bool = false
    public var timeZoneIdentifier: String?

    public init(iCalendar: String) {
        self.iCalendar = iCalendar
    }
}

public struct MessagingLink: Sendable, Hashable {
    public enum App: String, Sendable, Codable {
        case whatsApp, telegram, signal, viber, other
    }

    public var app: App
    public var recipient: String?
    public var prefilledText: String?
    public var url: URL

    public init(app: App, url: URL) {
        self.app = app
        self.url = url
    }
}

/// Codes that sign someone in, link a device or move authentication secrets.
public struct LoginCode: Sendable, Hashable {
    public enum Service: String, Sendable, Codable {
        case whatsAppWeb, telegram, discord, steam, passkey
        case authenticatorSetup, authenticatorExport, other
    }

    public var service: Service
    public var issuer: String?
    public var account: String?
    /// Number of accounts in this export chunk, when its structure can be decoded.
    public var accountCount: Int?
    public var batchSize: Int?

    public init(service: Service) {
        self.service = service
    }
}

/// An eSIM activation code (`LPA:1$…`) containing private installation details.
public struct ESIMActivation: Sendable, Hashable {
    public var smdpAddress: String
    public var matchingID: String?
    public var requiresConfirmationCode: Bool

    public init(smdpAddress: String, matchingID: String?, requiresConfirmationCode: Bool) {
        self.smdpAddress = smdpAddress
        self.matchingID = matchingID
        self.requiresConfirmationCode = requiresConfirmationCode
    }
}

/// Integrity of encoded data, not proof of the sender's identity.
public enum ChecksumStatus: String, Sendable, Codable {
    case notPresent, valid, invalid
}

extension Payload {
    public var kind: CodeKind {
        switch self {
        case .link: .link
        case .payment: .payment
        case .crypto: .crypto
        case .sms: .sms
        case .phone: .phone
        case .email: .email
        case .wifi: .wifi
        case .contact: .contact
        case .event: .event
        case .location: .location
        case .messaging: .messaging
        case .login: .login
        case .eSIM: .eSIM
        case .appLink: .appLink
        case .text: .text
        }
    }
}
