import SwiftUI
import ContactsUI
import EventKitUI
import NetworkExtension
import SafeQRKit

@MainActor @Observable
final class ActionHandler {
    enum Presentation: Identifiable {
        case share(String), contact(CNContact), event(EKEvent, EKEventStore)
        var id: String {
            switch self {
            case .share: "share"
            case .contact: "contact"
            case .event: "event"
            }
        }
    }

    var presentation: Presentation?
    var message: String?

    func perform(_ action: CodeAction, payload: Payload? = nil) async {
        do {
            switch action.kind {
            case .copy(let text):
                UIPasteboard.general.setItems([["public.utf8-plain-text": text]],
                                             options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(120)])
                message = L10n.text("Copied. The copy expires in two minutes.")
            case .share(let text):
                presentation = .share(text)
            case .joinWiFi(let ssid, let password, let security):
                guard !ssid.isEmpty, ssid.utf8.count <= 32 else { throw HandoffError.invalid }
                let configuration: NEHotspotConfiguration
                if security == .open {
                    configuration = NEHotspotConfiguration(ssid: ssid)
                } else if let password, !password.isEmpty {
                    configuration = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: security == .wep)
                } else {
                    throw HandoffError.invalid
                }
                configuration.joinOnce = true
                try await NEHotspotConfigurationManager.shared.apply(configuration)
                message = L10n.text("Connected for this session. You can leave the network in Settings.")
            case .addContact(let vCard):
                let contacts = try CNContactVCardSerialization.contacts(with: Data(vCard.utf8))
                guard contacts.count == 1, let contact = contacts.first else { throw HandoffError.invalid }
                presentation = .contact(contact)
            case .addEvent:
                guard case .event(let item) = payload, let start = item.start else { throw HandoffError.invalid }
                let store = EKEventStore()
                let event = EKEvent(eventStore: store)
                event.title = item.title ?? L10n.text("Scanned event")
                event.startDate = start
                event.endDate = max(item.end ?? start.addingTimeInterval(3600), start)
                event.location = item.location
                presentation = .event(event, store)
            default:
                guard let url = HandoffURLBuilder.url(for: action.kind) else { throw HandoffError.invalid }
                guard await UIApplication.shared.open(url) else { throw HandoffError.noApp }
            }
        } catch {
            message = L10n.text("This action could not be completed. Nothing was sent or saved by Safe QR.")
        }
    }
}

enum HandoffError: Error { case invalid, noApp }

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

struct ActionPresentationView: View {
    let presentation: ActionHandler.Presentation

    var body: some View {
        switch presentation {
        case .share(let text): ShareSheet(text: text)
        case .contact(let contact): ContactEditor(contact: contact)
        case .event(let event, let store): EventEditor(event: event, store: store)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private struct ContactEditor: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let contact: CNContact

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) { }

    @MainActor final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        nonisolated func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            Task { @MainActor in self.dismiss() }
        }
    }
}

private struct EventEditor: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let event: EKEvent
    let store: EKEventStore

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) { }

    @MainActor final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        nonisolated func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            Task { @MainActor in self.dismiss() }
        }
    }
}
