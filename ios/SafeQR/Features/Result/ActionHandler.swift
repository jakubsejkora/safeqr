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
                let zone = item.timeZoneIdentifier.flatMap { identifier in
                    TimeZone.knownTimeZoneIdentifiers.first { $0.uppercased() == identifier.uppercased() }
                        .flatMap(TimeZone.init(identifier:)) ?? TimeZone(identifier: identifier)
                }
                event.title = item.title ?? L10n.text("Scanned event")
                event.isAllDay = item.isAllDay
                event.timeZone = zone
                event.startDate = start
                // iCalendar's all-day end is exclusive; EventKit includes the supplied end day.
                event.endDate = item.isAllDay ? item.end?.addingTimeInterval(-1) ?? start : item.end ?? start
                event.location = item.location
                event.notes = item.description
                event.url = item.url.flatMap(URL.init(string:))
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

