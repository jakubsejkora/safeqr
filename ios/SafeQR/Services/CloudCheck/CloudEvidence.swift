import Foundation

struct LinkReport: Decodable, Sendable {
    struct Hop: Decodable, Sendable {
        let url: String
        let status: Int?
        let via: String
    }
    let finalUrl: String
    let hops: [Hop]
    let pageTitle: String?
    let screenshotUrl: URL?
    let domainAgeDays: Int?
    let asksFor: [String]?
}

struct SceneReport: Decodable, Sendable {
    let setting: String?
    let tamperingSigns: [String]?
    let matchesContent: Bool?
    let summary: String
}

struct ScamCase: Decodable, Sendable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let sourceUrl: URL
    let publishedAt: String
}
