#if DEBUG
import Foundation

enum DebugSample: String, CaseIterable, Identifiable {
    case training
    case link
    case http
    case lookalike
    case redirect
    case payment
    case paymentLink
    case sepa
    case invoice
    case swiss
    case emv
    case upi
    case payBySquare
    case crypto
    case sms
    case premiumSMS
    case phone
    case premiumCall
    case forwarding
    case email
    case emailHidden
    case wifi
    case wifiSecure
    case contact
    case bankContact
    case event
    case eventSubscription
    case location
    case messaging
    case login
    case authenticator
    case authExport
    case esim
    case appStore
    case enterprise
    case profile
    case text
    case textMixed

    var id: String { rawValue }
    var title: String { L10n.text(example.title) }
    var category: Category { example.category }
    var raw: String { example.payload }

    private var example: Example {
        switch self {
        case .training: Example(category: .links, title: "Parking scam (training)", payload: "https://safeqr-training.jakub-f9d.workers.dev/start")
        case .link: Example(category: .links, title: "Ordinary link", payload: "https://example.com/path")
        case .http: Example(category: .links, title: "Unencrypted link", payload: "http://example.com")
        case .lookalike: Example(category: .links, title: "Lookalike address", payload: "https://xn--pple-43d.test")
        case .redirect: Example(category: .links, title: "Hidden redirect", payload: "https://example.com/?next=https%3A%2F%2Fexample.org")
        case .payment: Example(category: .payments, title: "QR payment", payload: "SPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example")
        case .paymentLink: Example(category: .payments, title: "Payment with a hidden link", payload: "SPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example*X-URL:https%3A%2F%2Fexample.com/invoice")
        case .sepa: Example(category: .payments, title: "SEPA · foreign account", payload: "BCD\n002\n1\nSCT\n\nExample\nDE89370400440532013000\nEUR12.34\n\n\nCoffee")
        case .invoice: Example(category: .payments, title: "Invoice", payload: "SID*1.0*ID:DEMO-1*DD:20261019*AM:250*CC:CZK*ACC:CZ6508000000192000145399*RN:Example")
        case .swiss: Example(category: .payments, title: "Swiss payment", payload: "SPC\n0200\n1\nCH9300762011623852957\nS\nExample\nMain Street\n1\n8000\nZurich\nCH\n\n\n\n\n\n\n\n12.34\nCHF\n\n\n\n\n\n\n\nNON\n\nCoffee\nEPD")
        case .emv: Example(category: .payments, title: "Card payment · EMV", payload: "0002010216example-merchant5204599953032035406250.005802CZ5907Example6006Prague6304A1EC")
        case .upi: Example(category: .payments, title: "Indian payment · UPI", payload: "upi://pay?pa=example%40upi&pn=Example&am=25&cu=INR")
        case .payBySquare: Example(category: .payments, title: "Slovak payment · PAY by square", payload: "00018000041061050O3GG28A1C60Q3GF208H44OK2KB1E60P38DHO78")
        case .crypto: Example(category: .payments, title: "Cryptocurrency", payload: "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?amount=0.001")
        case .sms: Example(category: .phone, title: "Ordinary SMS", payload: "sms:+420777000000?body=Hello")
        case .premiumSMS: Example(category: .phone, title: "Premium SMS subscription", payload: "sms:90301099?body=START")
        case .phone: Example(category: .phone, title: "Phone call", payload: "tel:+420777000000")
        case .premiumCall: Example(category: .phone, title: "Premium-rate call", payload: "tel:900991234")
        case .forwarding: Example(category: .phone, title: "Call forwarding", payload: "tel:**21*+420777000000%23")
        case .email: Example(category: .everyday, title: "Email", payload: "mailto:person@example.com?subject=Hello&body=Test")
        case .emailHidden: Example(category: .everyday, title: "Email with a hidden recipient", payload: "mailto:person@example.com?bcc=other@example.org")
        case .wifi: Example(category: .everyday, title: "Open Wi-Fi", payload: "WIFI:T:nopass;S:Guest;;")
        case .wifiSecure: Example(category: .everyday, title: "Protected Wi-Fi", payload: "WIFI:T:WPA;S:Home;P:correct-horse;H:false;;")
        case .contact: Example(category: .everyday, title: "Contact", payload: "BEGIN:VCARD\nVERSION:3.0\nFN:Example Person\nTEL:+420777000000\nEND:VCARD")
        case .bankContact: Example(category: .everyday, title: "Contact claiming to be a bank", payload: "BEGIN:VCARD\nVERSION:3.0\nFN:Bank Security\nTEL:+420000000000\nEND:VCARD")
        case .event: Example(category: .everyday, title: "Calendar event", payload: "BEGIN:VEVENT\nSUMMARY:Example\nDTSTART:20261020T100000Z\nDTEND:20261020T110000Z\nEND:VEVENT")
        case .eventSubscription: Example(category: .everyday, title: "Event with a hidden subscription", payload: "BEGIN:VEVENT\nSUMMARY:Example\nDTSTART:20261020T100000Z\nDESCRIPTION:SMSTO:9030199:START\nEND:VEVENT")
        case .location: Example(category: .everyday, title: "Map location", payload: "geo:50.0755,14.4378?q=Prague")
        case .messaging: Example(category: .everyday, title: "WhatsApp message", payload: "https://wa.me/420777000000?text=Hello")
        case .login: Example(category: .access, title: "WhatsApp Web login", payload: "2@harmless-reference,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        case .authenticator: Example(category: .access, title: "Authenticator setup", payload: "otpauth://totp/Example:person?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        case .authExport: Example(category: .access, title: "Authenticator export", payload: "otpauth-migration://offline?data=CggKAwECAxIBQRABGAE=")
        case .esim: Example(category: .access, title: "eSIM activation", payload: "LPA:1$rsp.example.com$example-matching-id$$1")
        case .appStore: Example(category: .apps, title: "App Store", payload: "https://apps.apple.com/cz/app/example/id000000000")
        case .enterprise: Example(category: .apps, title: "Enterprise app installation", payload: "itms-services://?action=download-manifest&url=https://example.com/manifest.plist")
        case .profile: Example(category: .apps, title: "Device settings profile", payload: "https://example.com/settings.mobileconfig")
        case .text: Example(category: .everyday, title: "Plain text", payload: "Hello, world.")
        case .textMixed: Example(category: .everyday, title: "Text with a hidden paid SMS", payload: "Send this: smsto:9030199:START")
        }
    }

    private struct Example {
        let category: Category
        let title: String
        let payload: String
    }

    enum Category: CaseIterable, Identifiable {
        case links, payments, phone, everyday, access, apps
        var id: Self { self }
        var title: String {
            switch self {
            case .links: L10n.text("Links")
            case .payments: L10n.text("Payments")
            case .phone: L10n.text("SMS and calls")
            case .everyday: L10n.text("Everyday uses")
            case .access: L10n.text("Account access")
            case .apps: L10n.text("Apps and settings")
            }
        }
    }
}
#endif
