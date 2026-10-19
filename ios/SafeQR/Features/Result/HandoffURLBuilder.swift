import Foundation
import SafeQRKit

enum HandoffURLBuilder {
    static func url(for kind: CodeAction.Kind) -> URL? {
        var components = URLComponents()
        switch kind {
        case .open(let url):
            guard let scheme = url.scheme?.lowercased(),
                  !["javascript", "data", "file", "vbscript", "intent"].contains(scheme),
                  url.user == nil, url.password == nil else { return nil }
            return url
        case .call(let phone):
            guard let phone = phoneNumber(phone) else { return nil }
            components.scheme = "tel"
            components.path = phone
        case .sendSMS(let recipient, let body):
            guard let phone = phoneNumber(recipient) else { return nil }
            components.scheme = "sms"
            components.path = phone
            if let body { components.queryItems = [URLQueryItem(name: "body", value: body)] }
        case .composeEmail(let recipient, let subject, let body):
            guard !recipient.contains(where: { $0.isNewline }), !recipient.isEmpty else { return nil }
            components.scheme = "mailto"
            components.path = recipient
            components.queryItems = [subject.map { URLQueryItem(name: "subject", value: $0) },
                                     body.map { URLQueryItem(name: "body", value: $0) }].compactMap { $0 }
        default: return nil
        }
        return components.url
    }

    private static func phoneNumber(_ value: String) -> String? {
        let phone = value.filter { !$0.isWhitespace && $0 != "-" && $0 != "(" && $0 != ")" }
        guard !phone.isEmpty, phone.count <= 32,
              phone.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "+0123456789*#").contains($0) }) else { return nil }
        return phone
    }
}

extension CodeAction {
    var isHandoff: Bool {
        switch kind {
        case .copy, .share: false
        default: true
        }
    }

    var requiredConfirmation: Confirmation {
        confirmation ?? Confirmation(title: L10n.text("Continue outside Safe QR?"),
                                     message: L10n.text("Another app or a system screen will open. Review all details before you approve anything there."),
                                     confirmTitle: L10n.text("Continue"), isRisky: false)
    }
}

