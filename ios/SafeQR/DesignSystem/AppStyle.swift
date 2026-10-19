import SwiftUI
import SafeQRKit

enum L10n {
    static var locale: Locale { Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en") }

    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func format(_ key: String, _ values: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: values)
    }
}

enum AppStyle {
    static let accent = Color("AccentColor")
    static let onAccent = Color(uiColor: .systemBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

extension RiskLevel {
    var title: String {
        switch self {
        case .safe: L10n.text("Looks safe")
        case .caution: L10n.text("Be careful")
        case .danger: L10n.text("Dangerous")
        }
    }

    var symbol: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .caution: "exclamationmark.shield.fill"
        case .danger: "xmark.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: Color("VerdictSafe")
        case .caution: Color("VerdictCaution")
        case .danger: Color("VerdictDanger")
        }
    }
}

extension CodeKind {
    var symbol: String {
        switch self {
        case .link, .appLink: "link"
        case .payment: "banknote"
        case .crypto: "bitcoinsign.circle"
        case .sms, .messaging: "message"
        case .phone: "phone"
        case .email: "envelope"
        case .wifi: "wifi"
        case .contact: "person.crop.rectangle"
        case .event: "calendar"
        case .location: "map"
        case .login: "key"
        case .eSIM: "simcard"
        case .text: "text.alignleft"
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppStyle.card, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct ShieldMark: View {
    var size: CGFloat = 104

    var body: some View {
        Image(systemName: "qrcode.viewfinder")
            .font(.system(size: size * 0.58, weight: .medium))
            .foregroundStyle(AppStyle.accent)
            .frame(width: size, height: size)
            .background(AppStyle.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: size * 0.28))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: size * 0.31, weight: .semibold))
                    .foregroundStyle(AppStyle.accent)
                    .padding(4)
                    .background(.background, in: Circle())
                    .offset(x: 7, y: 7)
            }
            .accessibilityHidden(true)
    }
}
