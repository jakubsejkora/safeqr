import SwiftUI
import ContactsUI
import EventKitUI

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
