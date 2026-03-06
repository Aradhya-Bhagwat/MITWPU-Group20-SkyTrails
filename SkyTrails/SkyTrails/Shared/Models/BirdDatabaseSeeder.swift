
import Foundation
import SwiftData

@MainActor
final class BirdDatabaseSeeder {
    static let shared = BirdDatabaseSeeder()

    private init() {}

    private struct BirdDatabasePayload: Codable {
        let birds: [BirdDTO]
    }

    private struct BirdDTO: Codable {
        let bird_id: UUID
        let commonName: String
        let scientificName: String
        let staticImageName: String
        let family: String?
        let order_name: String?
        let descriptionText: String?
        let conservation_status: String?
        let validLocations: [String]?
        let validMonths: [Int]?
        let likelySpot: String?
        let shape_id: String?
        let size_category: Int?
        let fieldMarkData: [BirdFieldMarkDataDTO]?
    }

    private struct BirdFieldMarkDataDTO: Codable {
        let area: String
        let variantId: String
    }

    enum SeederError: Error {
        case fileNotFound
        case dataCorrupted
        case decodingFailed(Error)
    }

    func seed(modelContext: ModelContext) throws {
        let hasSeededKey = "kBirdDatabaseSeeded_v2"
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            return
        }

        guard let url = Bundle.main.url(forResource: "bird_database", withExtension: "json") else {
            throw SeederError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SeederError.dataCorrupted
        }

        let payload: BirdDatabasePayload
        do {
            payload = try JSONDecoder().decode(BirdDatabasePayload.self, from: data)
        } catch {
            throw SeederError.decodingFailed(error)
        }

        let birdDescriptor = FetchDescriptor<Bird>()
        let existingBirds = try modelContext.fetch(birdDescriptor)
        var existingBirdMap = Dictionary(uniqueKeysWithValues: existingBirds.map { ($0.bird_id, $0) })
        let shapes = try modelContext.fetch(FetchDescriptor<BirdShape>())
        let shapeById = Dictionary(uniqueKeysWithValues: shapes.map { ($0.bird_shape_id, $0) })
        let variants = try modelContext.fetch(FetchDescriptor<FieldMarkVariant>())
        let variantById = Dictionary(uniqueKeysWithValues: variants.map { ($0.field_mark_variant_id, $0) })

        for birdDTO in payload.birds {
            let normalizedLikelySpot = normalizeLikelySpot(birdDTO.likelySpot)
            let normalizedValidLocations = normalizeValidLocations(birdDTO.validLocations)

            if let existing = existingBirdMap[birdDTO.bird_id] {
                var didUpdate = false

                if existing.commonName.isEmpty {
                    existing.commonName = birdDTO.commonName
                    didUpdate = true
                }
                if existing.scientificName.isEmpty {
                    existing.scientificName = birdDTO.scientificName
                    didUpdate = true
                }
                if existing.staticImageName.isEmpty {
                    existing.staticImageName = birdDTO.staticImageName
                    didUpdate = true
                }
                if existing.family == nil, let family = birdDTO.family {
                    existing.family = family
                    didUpdate = true
                }
                if existing.order_name == nil, let order = birdDTO.order_name {
                    existing.order_name = order
                    didUpdate = true
                }
                if existing.descriptionText == nil, let description = birdDTO.descriptionText {
                    existing.descriptionText = description
                    didUpdate = true
                }
                if existing.conservation_status == nil, let status = birdDTO.conservation_status {
                    existing.conservation_status = status
                    didUpdate = true
                }
                if (existing.validLocations == nil || existing.validLocations?.isEmpty == true),
                   let validLocations = normalizedValidLocations {
                    existing.validLocations = validLocations
                    didUpdate = true
                }
                if (existing.validMonths == nil || existing.validMonths?.isEmpty == true),
                   let validMonths = birdDTO.validMonths {
                    existing.validMonths = validMonths
                    didUpdate = true
                }
                if existing.likelySpot == nil, let likelySpot = normalizedLikelySpot {
                    existing.likelySpot = likelySpot
                    didUpdate = true
                }
                if existing.shape_id == nil, let shapeId = birdDTO.shape_id {
                    existing.shape_id = shapeId
                    didUpdate = true
                }
                if existing.shape == nil,
                   let shapeId = birdDTO.shape_id,
                   let shape = shapeById[shapeId] {
                    existing.shape = shape
                    didUpdate = true
                }
                if existing.size_category == nil, let sizeCategory = birdDTO.size_category {
                    existing.size_category = sizeCategory
                    didUpdate = true
                }
                if upsertBirdMarkLinks(
                    bird: existing,
                    markDTOs: birdDTO.fieldMarkData,
                    variantById: variantById,
                    modelContext: modelContext
                ) {
                    didUpdate = true
                }

                if didUpdate {
                    modelContext.insert(existing)
                }
                continue
            }

            let bird = Bird(bird_id: birdDTO.bird_id,
                commonName: birdDTO.commonName,
                scientificName: birdDTO.scientificName,
                staticImageName: birdDTO.staticImageName,
                family: birdDTO.family,
                order_name: birdDTO.order_name,
                descriptionText: birdDTO.descriptionText,
                conservation_status: birdDTO.conservation_status,
                migration_strategy: nil,
                validLocations: normalizedValidLocations,
                validMonths: birdDTO.validMonths,
                likelySpot: normalizedLikelySpot,
                shape_id: birdDTO.shape_id,
                size_category: birdDTO.size_category,
                shape: birdDTO.shape_id.flatMap { shapeById[$0] }
            )
            _ = upsertBirdMarkLinks(
                bird: bird,
                markDTOs: birdDTO.fieldMarkData,
                variantById: variantById,
                modelContext: modelContext
            )
            modelContext.insert(bird)
            existingBirdMap[bird.bird_id] = bird
        }

        try modelContext.save()
        UserDefaults.standard.set(true, forKey: hasSeededKey)
    }

    @discardableResult
    private func upsertBirdMarkLinks(
        bird: Bird,
        markDTOs: [BirdFieldMarkDataDTO]?,
        variantById: [UUID: FieldMarkVariant],
        modelContext: ModelContext
    ) -> Bool {
        guard let markDTOs, !markDTOs.isEmpty else { return false }

        var didChange = false
        var existingKeys = Set<String>()
        if let links = bird.fieldMarkLinks {
            for link in links {
                if let variantId = link.variant?.field_mark_variant_id {
                    existingKeys.insert("\(link.area.lowercased())|\(variantId.uuidString.lowercased())")
                }
            }
        }

        for mark in markDTOs {
            guard let variantUUID = UUID(uuidString: mark.variantId),
                  let variant = variantById[variantUUID] else {
                continue
            }
            let area = mark.area
            let key = "\(area.lowercased())|\(variantUUID.uuidString.lowercased())"
            if existingKeys.contains(key) {
                continue
            }

            let link = BirdFieldMarkVariantLink(
                bird: bird,
                fieldMark: variant.fieldMark,
                variant: variant,
                area: area
            )
            modelContext.insert(link)
            existingKeys.insert(key)
            didChange = true
        }

        return didChange
    }

    private func normalizeLikelySpot(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "wetland":
            return "Wetlands"
        default:
            return trimmed
        }
    }

    private func normalizeValidLocations(_ raw: [String]?) -> [String]? {
        guard let raw else { return nil }
        var seen = Set<String>()
        let normalized = raw.compactMap { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let mapped: String
            switch trimmed.lowercased() {
            case "dessert", "desert":
                mapped = "Thar Desert, Rajasthan"
            case "urban", "pune, india":
                mapped = "Pune, Maharashtra"
            case "wetlands":
                mapped = "Bharatpur, Rajasthan"
            case "himalayas":
                mapped = "Himalayan Region, Uttarakhand"
            case "western ghats":
                mapped = "Western Ghats, Kerala"
            default:
                mapped = trimmed
            }
            if mapped.isEmpty || seen.contains(mapped) { return nil }
            seen.insert(mapped)
            return mapped
        }
        return normalized.isEmpty ? nil : normalized
    }
}
