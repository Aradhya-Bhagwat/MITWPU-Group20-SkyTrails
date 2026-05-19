import Foundation
import SwiftData

@MainActor
final class BirdReferenceInfoSeeder {
    static let shared = BirdReferenceInfoSeeder()

    private init() {
    }

    private struct BundlePayload: Decodable {
        let version: Int
        let recordCount: Int
        let records: [Record]

        enum CodingKeys: String, CodingKey {
            case version
            case recordCount = "record_count"
            case records
        }
    }

    private struct Record: Decodable {
        let speciesCode: String
        let commonName: String
        let scientificName: String
        let wikiTitle: String?
        let sourceURL: String?
        let fieldMarks: String?
        let size: String?
        let weight: String?
        let habitat: String?
        let behavior: String?
        let similarSpecies: String?
        let family: String?
        let orderName: String?
        let genus: String?
        let notes: String?

        enum CodingKeys: String, CodingKey {
            case speciesCode = "species_code"
            case commonName = "common_name"
            case scientificName = "scientific_name"
            case wikiTitle = "wiki_title"
            case sourceURL = "source_url"
            case fieldMarks = "field_marks"
            case size
            case weight
            case habitat
            case behavior
            case similarSpecies = "similar_species"
            case family
            case orderName = "order"
            case genus
            case notes
        }
    }

    enum SeederError: Error {
        case fileNotFound
    }

    func seed(modelContext: ModelContext) throws {
        let hasSeededKey = "kBirdReferenceInfoSeeded_v1"
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            return
        }

        let payload = try loadPayload()
        let existingRecords = try modelContext.fetch(FetchDescriptor<BirdReferenceInfo>())
        var existingByCode = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.speciesCode, $0) })

        for record in payload.records {
            let info = existingByCode[record.speciesCode] ?? BirdReferenceInfo(
                speciesCode: record.speciesCode,
                commonName: record.commonName,
                scientificName: record.scientificName
            )

            info.commonName = record.commonName
            info.scientificName = record.scientificName
            info.wikiTitle = record.wikiTitle
            info.sourceURL = record.sourceURL
            info.fieldMarks = normalized(record.fieldMarks)
            info.size = normalized(record.size)
            info.weight = normalized(record.weight)
            info.habitat = normalized(record.habitat)
            info.behavior = normalized(record.behavior)
            info.similarSpecies = normalized(record.similarSpecies)
            info.family = normalized(record.family)
            info.orderName = normalized(record.orderName)
            info.genus = normalized(record.genus)
            info.notes = normalized(record.notes)

            if existingByCode[record.speciesCode] == nil {
                modelContext.insert(info)
                existingByCode[record.speciesCode] = info
            }
        }

        try modelContext.save()
        UserDefaults.standard.set(true, forKey: hasSeededKey)
    }

    private func loadPayload() throws -> BundlePayload {
        let data = try loadBundleData()
        return try JSONDecoder().decode(BundlePayload.self, from: data)
    }

    private func loadBundleData() throws -> Data {
        if let jsonURL = Bundle.main.url(forResource: "bird_reference_info", withExtension: "json") {
            return try Data(contentsOf: jsonURL)
        }

        throw SeederError.fileNotFound
    }

    private func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
