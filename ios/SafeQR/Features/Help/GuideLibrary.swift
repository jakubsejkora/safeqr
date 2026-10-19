import Foundation

struct BilingualText: Decodable, Sendable, Hashable {
    let en: String
    let cs: String
    var value: String { L10n.locale.language.languageCode?.identifier == "cs" ? cs : en }
}

struct SafetyGuide: Decodable, Identifiable, Hashable {
    struct Block: Decodable, Hashable {
        let text: BilingualText
        let numbered: Bool
    }
    struct Source: Decodable, Hashable, Identifiable {
        let title: BilingualText
        let url: URL
        var id: URL { url }
    }
    let id: String
    let category: String
    let symbol: String
    let title: BilingualText
    let blocks: [Block]
    let sources: [Source]
}

struct BankHotline: Decodable, Identifiable {
    let id: String
    let bank: String
    let phone: String
    let scope: BilingualText
    let hours: BilingualText
    let source: URL
}

struct GuideLibrary {
    let guides: [SafetyGuide]
    let banks: [BankHotline]
    let loadFailed: Bool

    init(bundle: Bundle = .main) {
        do {
            guard let guideURL = bundle.url(forResource: "guides", withExtension: "json"),
                  let bankURL = bundle.url(forResource: "bank-hotlines", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let decodedGuides = try JSONDecoder().decode([SafetyGuide].self, from: Data(contentsOf: guideURL))
            let decodedBanks = try JSONDecoder().decode([BankHotline].self, from: Data(contentsOf: bankURL))
            guides = decodedGuides
            banks = decodedBanks
            loadFailed = false
        } catch {
            guides = []
            banks = []
            loadFailed = true
        }
    }
}
