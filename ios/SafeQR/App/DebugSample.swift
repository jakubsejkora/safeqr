#if DEBUG
import Foundation

enum DebugSample: String, CaseIterable, Identifiable {
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
    var title: String { L10n.locale.language.languageCode?.identifier == "cs" ? example.czech : example.english }
    var category: Category { example.category }
    var raw: String { example.payload }

    private var example: Example {
        switch self {
        case .link: Example(category: .links, english: "Ordinary link", czech: "Běžný odkaz", payload: "https://example.com/path")
        case .http: Example(category: .links, english: "Unencrypted link", czech: "Nezabezpečený odkaz", payload: "http://example.com")
        case .lookalike: Example(category: .links, english: "Lookalike address", czech: "Napodobená adresa", payload: "https://xn--pple-43d.test")
        case .redirect: Example(category: .links, english: "Hidden redirect", czech: "Skryté přesměrování", payload: "https://example.com/?next=https%3A%2F%2Fexample.org")
        case .payment: Example(category: .payments, english: "QR payment", czech: "QR platba", payload: "SPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example")
        case .paymentLink: Example(category: .payments, english: "Payment with a hidden link", czech: "Platba se skrytým odkazem", payload: "SPD*1.0*ACC:CZ6508000000192000145399*AM:250*CC:CZK*RN:Example*X-URL:https%3A%2F%2Fexample.com/invoice")
        case .sepa: Example(category: .payments, english: "SEPA · foreign account", czech: "SEPA · zahraniční účet", payload: "BCD\n002\n1\nSCT\n\nExample\nDE89370400440532013000\nEUR12.34\n\n\nCoffee")
        case .invoice: Example(category: .payments, english: "Invoice", czech: "Faktura", payload: "SID*1.0*ID:DEMO-1*DD:20261019*AM:250*CC:CZK*ACC:CZ6508000000192000145399*RN:Example")
        case .swiss: Example(category: .payments, english: "Swiss payment", czech: "Švýcarská platba", payload: "SPC\n0200\n1\nCH9300762011623852957\nS\nExample\nMain Street\n1\n8000\nZurich\nCH\n\n\n\n\n\n\n\n12.34\nCHF\n\n\n\n\n\n\n\nNON\n\nCoffee\nEPD")
        case .emv: Example(category: .payments, english: "Card payment · EMV", czech: "Platba kartou · EMV", payload: "0002010216example-merchant5204599953032035406250.005802CZ5907Example6006Prague6304A1EC")
        case .upi: Example(category: .payments, english: "Indian payment · UPI", czech: "Indická platba · UPI", payload: "upi://pay?pa=example%40upi&pn=Example&am=25&cu=INR")
        case .payBySquare: Example(category: .payments, english: "Slovak payment · PAY by square", czech: "Slovenská platba · PAY by square", payload: "00018000041061050O3GG28A1C60Q3GF208H44OK2KB1E60P38DHO78")
        case .crypto: Example(category: .payments, english: "Cryptocurrency", czech: "Kryptoměna", payload: "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?amount=0.001")
        case .sms: Example(category: .phone, english: "Ordinary SMS", czech: "Běžná SMS", payload: "sms:+420777000000?body=Hello")
        case .premiumSMS: Example(category: .phone, english: "Premium SMS subscription", czech: "Předplatné přes prémiovou SMS", payload: "sms:90301099?body=START")
        case .phone: Example(category: .phone, english: "Phone call", czech: "Telefonní hovor", payload: "tel:+420777000000")
        case .premiumCall: Example(category: .phone, english: "Premium-rate call", czech: "Drahý placený hovor", payload: "tel:900991234")
        case .forwarding: Example(category: .phone, english: "Call forwarding", czech: "Přesměrování hovorů", payload: "tel:**21*+420777000000%23")
        case .email: Example(category: .everyday, english: "Email", czech: "E-mail", payload: "mailto:person@example.com?subject=Hello&body=Test")
        case .emailHidden: Example(category: .everyday, english: "Email with a hidden recipient", czech: "E-mail se skrytým příjemcem", payload: "mailto:person@example.com?bcc=other@example.org")
        case .wifi: Example(category: .everyday, english: "Open Wi-Fi", czech: "Otevřená Wi-Fi", payload: "WIFI:T:nopass;S:Guest;;")
        case .wifiSecure: Example(category: .everyday, english: "Protected Wi-Fi", czech: "Zabezpečená Wi-Fi", payload: "WIFI:T:WPA;S:Home;P:correct-horse;H:false;;")
        case .contact: Example(category: .everyday, english: "Contact", czech: "Kontakt", payload: "BEGIN:VCARD\nVERSION:3.0\nFN:Example Person\nTEL:+420777000000\nEND:VCARD")
        case .bankContact: Example(category: .everyday, english: "Contact claiming to be a bank", czech: "Kontakt vydávající se za banku", payload: "BEGIN:VCARD\nVERSION:3.0\nFN:Bank Security\nTEL:+420000000000\nEND:VCARD")
        case .event: Example(category: .everyday, english: "Calendar event", czech: "Událost v kalendáři", payload: "BEGIN:VEVENT\nSUMMARY:Example\nDTSTART:20261020T100000Z\nDTEND:20261020T110000Z\nEND:VEVENT")
        case .eventSubscription: Example(category: .everyday, english: "Event with a hidden subscription", czech: "Událost se skrytým předplatným", payload: "BEGIN:VEVENT\nSUMMARY:Example\nDTSTART:20261020T100000Z\nDESCRIPTION:SMSTO:9030199:START\nEND:VEVENT")
        case .location: Example(category: .everyday, english: "Map location", czech: "Místo na mapě", payload: "geo:50.0755,14.4378?q=Prague")
        case .messaging: Example(category: .everyday, english: "WhatsApp message", czech: "Zpráva přes WhatsApp", payload: "https://wa.me/420777000000?text=Hello")
        case .login: Example(category: .access, english: "WhatsApp Web login", czech: "Přihlášení do WhatsApp Web", payload: "2@harmless-reference,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=,AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        case .authenticator: Example(category: .access, english: "Authenticator setup", czech: "Nastavení ověřovací aplikace", payload: "otpauth://totp/Example:person?secret=JBSWY3DPEHPK3PXP&issuer=Example")
        case .authExport: Example(category: .access, english: "Authenticator export", czech: "Export ověřovacích klíčů", payload: "otpauth-migration://offline?data=CggKAwECAxIBQRABGAE=")
        case .esim: Example(category: .access, english: "eSIM activation", czech: "Aktivace eSIM", payload: "LPA:1$rsp.example.com$example-matching-id$$1")
        case .appStore: Example(category: .apps, english: "App Store", czech: "App Store", payload: "https://apps.apple.com/cz/app/example/id000000000")
        case .enterprise: Example(category: .apps, english: "Enterprise app installation", czech: "Instalace podnikové aplikace", payload: "itms-services://?action=download-manifest&url=https://example.com/manifest.plist")
        case .profile: Example(category: .apps, english: "Device settings profile", czech: "Profil nastavení telefonu", payload: "https://example.com/settings.mobileconfig")
        case .text: Example(category: .everyday, english: "Plain text", czech: "Obyčejný text", payload: "Hello, world.")
        case .textMixed: Example(category: .everyday, english: "Text with a hidden paid SMS", czech: "Text se skrytou placenou SMS", payload: "Send this: smsto:9030199:START")
        }
    }

    private struct Example {
        let category: Category
        let english: String
        let czech: String
        let payload: String
    }

    enum Category: CaseIterable, Identifiable {
        case links, payments, phone, everyday, access, apps
        var id: Self { self }
        var title: String {
            let czech = L10n.locale.language.languageCode?.identifier == "cs"
            return switch self {
            case .links: czech ? "Odkazy" : "Links"
            case .payments: czech ? "Platby" : "Payments"
            case .phone: czech ? "SMS a volání" : "SMS and calls"
            case .everyday: czech ? "Každodenní použití" : "Everyday uses"
            case .access: czech ? "Přístup k účtům" : "Account access"
            case .apps: czech ? "Aplikace a nastavení" : "Apps and settings"
            }
        }
    }
}
#endif
