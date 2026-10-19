import SwiftUI
import SafeQRKit

struct FactRow: View {
    let fact: Fact
    @ScaledMetric(relativeTo: .body) private var bodySize = 17
    @ScaledMetric(relativeTo: .title3) private var primarySize = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fact.label).font(.subheadline).foregroundStyle(.secondary)
            SelectableValue(
                text: fact.value,
                font: .systemFont(ofSize: fact.emphasis == .primary ? primarySize : bodySize,
                                  weight: fact.emphasis == .primary ? .semibold : .regular),
                color: fact.emphasis == .warning ? UIColor(named: "VerdictCaution") ?? .label : .label
            )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SelectableValue: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.dataDetectorTypes = []
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        // Added hyphens could be mistaken for characters in an address or account number.
        paragraph.hyphenationFactor = 0
        paragraph.usesDefaultHyphenation = false
        view.attributedText = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
