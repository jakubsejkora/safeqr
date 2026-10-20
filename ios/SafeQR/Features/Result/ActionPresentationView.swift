import SwiftUI
import ContactsUI
import EventKitUI
import LinkPresentation

struct ActionPresentationView: View {
    let presentation: ActionHandler.Presentation

    var body: some View {
        switch presentation {
        case .share(let text): ShareSheet(text: text)
        case .paymentImage(let image): PaymentImageShareSheet(image: image)
        case .contact(let contact): ContactEditor(contact: contact)
        case .event(let event, let store): EventEditor(event: event, store: store)
        }
    }
}

private struct PaymentImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [PaymentImageItem(image: image)], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

private final class PaymentImageItem: NSObject, UIActivityItemSource {
    let image: UIImage

    init(image: UIImage) { self.image = image }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { image }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { image }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = L10n.text("Payment")
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
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
