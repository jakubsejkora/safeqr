import Foundation
import Observation
import SwiftData
import SafeQRKit

@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var score: Int
    var kind: String

    init(analysis: CodeAnalysis, assessment: RiskAssessment, date: Date = .now) {
        id = analysis.id
        self.date = date
        title = analysis.content.title
        score = assessment.score
        kind = analysis.content.kind.rawValue
    }
}

@MainActor @Observable
final class HistoryStore {
    private let container: ModelContainer
    private(set) var records: [ScanRecord] = []
    var errorMessage: String?

    init(inMemory: Bool = false) throws {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            let directory = URL.applicationSupportDirectory.appending(path: "PrivateHistory", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedDirectory = directory
            try protectedDirectory.setResourceValues(values)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
            configuration = ModelConfiguration(url: directory.appending(path: "history.store"), cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: ScanRecord.self, configurations: configuration)
        try reload()
    }

    func record(_ analysis: CodeAnalysis, assessment: RiskAssessment, enabled: Bool) {
        guard enabled else { return }
        // Store a verdict summary only. Raw codes, photos, credentials and action targets are never persisted.
        if let existing = records.first(where: { $0.id == analysis.id }) {
            existing.score = assessment.score
        } else {
            container.mainContext.insert(ScanRecord(analysis: analysis, assessment: assessment))
        }
        save()
    }

    func delete(_ record: ScanRecord) {
        container.mainContext.delete(record)
        save()
    }

    func clear() {
        do {
            try container.mainContext.delete(model: ScanRecord.self)
            try container.mainContext.save()
            try reload()
        } catch {
            errorMessage = L10n.text("History could not be updated. Please try again.")
        }
    }

    private func save() {
        do {
            try container.mainContext.save()
            try reload()
        } catch {
            errorMessage = L10n.text("History could not be updated. Please try again.")
        }
    }

    private func reload() throws {
        records = try container.mainContext.fetch(FetchDescriptor<ScanRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }
}
