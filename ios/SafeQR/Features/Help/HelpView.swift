import SwiftUI
import SafeQRKit

struct HelpView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var navigation = services.navigation
        NavigationStack(path: $navigation.guides) {
            List {
                if services.guides.loadFailed {
                    Text(L10n.text("The guides could not be loaded. If money is at risk, call your bank using the number on your card."))
                }
                Section(L10n.text("Need help now?")) {
                    NavigationLink { BankHotlinesView() } label: {
                        Label(L10n.text("Call your bank"), systemImage: "phone.arrow.up.right")
                    }
                    NavigationLink { GuideListView(category: "recovery", title: L10n.text("Scam recovery")) } label: {
                        Label(L10n.text("Something has gone wrong"), systemImage: "lifepreserver")
                    }
                    if let card = services.guides.guides.first(where: { $0.id == "recovery-2" }) {
                        NavigationLink(value: card) { Label(L10n.text("Block a card"), systemImage: "creditcard") }
                    }
                    ConfirmedActionButton(action: phoneAction(name: L10n.text("Czech Police"), number: "158"), symbol: "phone")
                    ConfirmedActionButton(action: phoneAction(name: L10n.text("Emergency services"), number: "112"), symbol: "phone")
                    if let report = services.guides.guides.first(where: { $0.id == "report" }) {
                        NavigationLink(value: report) { Label(report.title.value, systemImage: report.symbol) }
                    }
                }
                guideSection("basics", title: L10n.text("Start here"))
                Section(L10n.text("Prevent unwanted charges")) {
                    NavigationLink { GuideListView(category: "operator", title: L10n.text("Operator protection")) } label: {
                        Label(L10n.text("Operator protection"), systemImage: "iphone.slash")
                    }
                }
                Section {
                    Text(L10n.text("Sources reviewed on 19 October 2026. Phone numbers were checked against official websites, not test-called."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.text("Help"))
            .navigationDestination(for: SafetyGuide.self) { GuideDetailView(guide: $0) }
        }
    }

    private func guideSection(_ category: String, title: String) -> some View {
        Section(title) {
            ForEach(services.guides.guides.filter { $0.category == category }) { guide in
                NavigationLink(value: guide) { Label(guide.title.value, systemImage: guide.symbol) }
            }
        }
    }
}

struct GuideListView: View {
    @Environment(AppServices.self) private var services
    let category: String
    let title: String

    var body: some View {
        List(services.guides.guides.filter { $0.category == category }) { guide in
            NavigationLink { GuideDetailView(guide: guide) } label: {
                Label(guide.title.value, systemImage: guide.symbol).padding(.vertical, 6)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct GuideDetailView: View {
    @Environment(\.appTheme) private var theme

    let guide: SafetyGuide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(guide.title.value).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                ForEach(Array(guide.blocks.enumerated()), id: \.offset) { index, block in
                    HStack(alignment: .top, spacing: 16) {
                        if block.numbered {
                            let number = guide.blocks.prefix(index + 1).filter(\.numbered).count
                            Text(number.formatted()).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(.secondary).frame(minWidth: 36, alignment: .leading)
                                .accessibilityLabel(L10n.format("Step %lld", number))
                        }
                        Text((try? AttributedString(markdown: block.text.value)) ?? AttributedString(block.text.value))
                            .font(.body).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if guide.id.hasPrefix("recovery-") {
                    NavigationLink { BankHotlinesView() } label: { Label(L10n.text("Find your bank’s number"), systemImage: "phone") }
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(theme.onAccent).controlSize(.large)
                }
                if guide.id == "report" {
                    ConfirmedActionButton(action: phoneAction(name: L10n.text("Czech Police"), number: "158"), symbol: "phone")
                        .buttonStyle(.glassProminent)
                        .foregroundStyle(theme.onAccent).controlSize(.large)
                }
                if !guide.sources.isEmpty {
                    DetailSection(title: L10n.text("Official sources")) {
                        Text(L10n.text("Reviewed on 19 October 2026")).font(.footnote).foregroundStyle(.secondary)
                        ForEach(guide.sources) { source in
                            ConfirmedActionButton(action: sourceAction(title: source.title.value, url: source.url))
                                .frame(minHeight: 44)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(AppStyle.canvas)
        .navigationTitle(L10n.text("Step by step"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BankHotlinesView: View {
    @Environment(AppServices.self) private var services
    @State private var query = ""

    var body: some View {
        List {
            Section {
                Text(L10n.text("If money is at risk, call now. Card blocking may not block access to your account. Choose the line for what happened."))
            }
            ForEach(services.guides.banks.filter { query.isEmpty || $0.bank.localizedStandardContains(query) }) { bank in
                Section(bank.bank) {
                    Text(bank.scope.value)
                    Text(bank.hours.value).font(.subheadline).foregroundStyle(.secondary)
                    ConfirmedActionButton(action: phoneAction(name: bank.bank, number: bank.phone))
                        .font(.headline).frame(minHeight: 44)
                    ConfirmedActionButton(action: sourceAction(title: L10n.text("Official contact page"), url: bank.source))
                }
            }
        }
        .searchable(text: $query, prompt: L10n.text("Your bank"))
        .navigationTitle(L10n.text("Call your bank"))
    }
}

func phoneAction(name: String, number: String) -> CodeAction {
    let title: String
    let question: String
    switch number {
    case "112":
        title = L10n.format("Call emergency services · %@", number)
        question = L10n.text("Call emergency services?")
    case "158":
        title = L10n.format("Call Czech Police · %@", number)
        question = L10n.text("Call Czech Police?")
    default:
        title = L10n.format("Call %@ · %@", name, number)
        question = L10n.format("Call %@?", name)
    }
    return CodeAction(id: number, kind: .call(phoneNumber: number), title: title,
               confirmation: Confirmation(title: question,
                                          message: L10n.format(["158", "112"].contains(number) ? "Your iPhone will call %@."
                                                               : "Your iPhone will call %@. Your operator’s usual call charges may apply.", number),
                                          confirmTitle: L10n.text("Call"), isRisky: false))
}
