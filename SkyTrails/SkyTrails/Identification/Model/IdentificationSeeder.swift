import Foundation
import SwiftData

@MainActor
final class IdentificationSeeder {

    private struct BirdDB: Codable {
        let reference_data: ReferenceData
        let birds: [BirdDTO]
    }

    private struct ReferenceData: Codable {
        let shapes: [ShapeDTO]
        let fieldMarks: [FieldMarkDTO]
        let variants: [VariantDTO]
    }

    private struct ShapeDTO: Codable {
        let id: String
        let name: String
        let icon: String
    }
    
    private struct FieldMarkDTO: Codable {
        let id: String
        let shapeId: String
        let area: String
    }
    
    private struct VariantDTO: Codable {
        let id: String
        let fieldMarkId: String
        let name: String
    }
    
    private struct BirdDTO: Codable {
        let id: UUID
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

    func seed(context: ModelContext) throws {

        let shapeCount = try context.fetchCount(FetchDescriptor<BirdShape>())
        let fieldMarkCount = try context.fetchCount(FetchDescriptor<BirdFieldMark>())
        let variantCount = try context.fetchCount(FetchDescriptor<FieldMarkVariant>())
        let linkedFieldMarkCount = try context.fetchCount(
            FetchDescriptor<BirdFieldMark>(predicate: #Predicate<BirdFieldMark> { mark in
                mark.shape != nil
            })
        )
        let linkedVariantCount = try context.fetchCount(
            FetchDescriptor<FieldMarkVariant>(predicate: #Predicate<FieldMarkVariant> { variant in
                variant.fieldMark != nil
            })
        )
        let identificationBirdCount = try context.fetchCount(
            FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
                bird.shape != nil && bird.size_category != nil
            })
        )
        let needsSeeding =
            shapeCount == 0 ||
            fieldMarkCount == 0 ||
            variantCount == 0 ||
            identificationBirdCount == 0 ||
            linkedFieldMarkCount < fieldMarkCount ||
            linkedVariantCount < variantCount
        guard needsSeeding else { return }

        try BirdDatabaseSeeder.shared.seed(modelContext: context)

        guard let url = Bundle.main.url(
            forResource: "bird_database",
            withExtension: "json"
        ) else {
            throw SeederError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let db = try JSONDecoder().decode(BirdDB.self, from: data)

        let existingShapes = try context.fetch(FetchDescriptor<BirdShape>())
        var shapeMap = Dictionary(uniqueKeysWithValues: existingShapes.map { ($0.id, $0) })

        let existingFieldMarks = try context.fetch(FetchDescriptor<BirdFieldMark>())
        var fieldMarkMap: [String: BirdFieldMark] = [:]
        for fieldMark in existingFieldMarks {
            fieldMarkMap[fieldMark.id.uuidString.lowercased()] = fieldMark
        }

        let existingVariants = try context.fetch(FetchDescriptor<FieldMarkVariant>())
        var variantMap: [String: FieldMarkVariant] = [:]
        for variant in existingVariants {
            variantMap[variant.id.uuidString.lowercased()] = variant
        }

        let existingBirds = try context.fetch(FetchDescriptor<Bird>())
        let existingBirdMap = Dictionary(uniqueKeysWithValues: existingBirds.map { ($0.id, $0) })
        for shapeDTO in db.reference_data.shapes {
            if let existing = shapeMap[shapeDTO.id] {
                var didUpdate = false
                if existing.name != shapeDTO.name {
                    existing.name = shapeDTO.name
                    didUpdate = true
                }
                if existing.icon != shapeDTO.icon {
                    existing.icon = shapeDTO.icon
                    didUpdate = true
                }
                if didUpdate {
                    context.insert(existing)
                }
                continue
            }
            let shape = BirdShape(
                id: shapeDTO.id,
                name: shapeDTO.name,
                icon: shapeDTO.icon
            )
            context.insert(shape)
            shapeMap[shapeDTO.id] = shape
        }
        for fieldMarkDTO in db.reference_data.fieldMarks {
            let fieldMarkKey = fieldMarkDTO.id.lowercased()
            let fieldMarkId = UUID(uuidString: fieldMarkDTO.id) ?? UUID()
            if let existing = fieldMarkMap[fieldMarkKey] {
                var didUpdate = false
                if existing.area != fieldMarkDTO.area {
                    existing.area = fieldMarkDTO.area
                    didUpdate = true
                }
                if existing.shape?.id != fieldMarkDTO.shapeId,
                   let shape = shapeMap[fieldMarkDTO.shapeId] {
                    existing.shape = shape
                    didUpdate = true
                }
                if didUpdate {
                    context.insert(existing)
                }
                continue
            }
            let fieldMark = BirdFieldMark(area: fieldMarkDTO.area)
            fieldMark.id = fieldMarkId
            if let shape = shapeMap[fieldMarkDTO.shapeId] {
                fieldMark.shape = shape
            }
            
            context.insert(fieldMark)
            fieldMarkMap[fieldMarkKey] = fieldMark
        }
        for variantDTO in db.reference_data.variants {
            let variantKey = variantDTO.id.lowercased()
            let variantId = UUID(uuidString: variantDTO.id) ?? UUID()
            if let existing = variantMap[variantKey] {
                var didUpdate = false
                if existing.name != variantDTO.name {
                    existing.name = variantDTO.name
                    didUpdate = true
                }
                if existing.fieldMark?.id.uuidString.lowercased() != variantDTO.fieldMarkId.lowercased(),
                   let fieldMark = fieldMarkMap[variantDTO.fieldMarkId.lowercased()] {
                    existing.fieldMark = fieldMark
                    didUpdate = true
                }
                if didUpdate {
                    context.insert(existing)
                }
                continue
            }
            let variant = FieldMarkVariant(name: variantDTO.name)
            variant.id = variantId
            if let fieldMark = fieldMarkMap[variantDTO.fieldMarkId.lowercased()] {
                variant.fieldMark = fieldMark
            }
            
            context.insert(variant)
            variantMap[variantKey] = variant
        }
        for birdDTO in db.birds {
            let normalizedLikelySpot = normalizeLikelySpot(birdDTO.likelySpot)
            let normalizedValidLocations = normalizeValidLocations(birdDTO.validLocations)

            if let existing = existingBirdMap[birdDTO.id] {
                var didUpdate = false
                if existing.shape_id == nil, let shapeId = birdDTO.shape_id {
                    existing.shape_id = shapeId
                    didUpdate = true
                }
                if existing.shape == nil,
                   let shapeId = birdDTO.shape_id,
                   let shape = shapeMap[shapeId] {
                    existing.shape = shape
                    didUpdate = true
                }
                if existing.size_category == nil, let sizeCategory = birdDTO.size_category {
                    existing.size_category = sizeCategory
                    didUpdate = true
                }
                if (existing.validMonths == nil || existing.validMonths?.isEmpty == true),
                   let validMonths = birdDTO.validMonths {
                    existing.validMonths = validMonths
                    didUpdate = true
                }
                if (existing.validLocations == nil || existing.validLocations?.isEmpty == true),
                   let validLocations = normalizedValidLocations {
                    existing.validLocations = validLocations
                    didUpdate = true
                }
                if existing.likelySpot == nil, let likelySpot = normalizedLikelySpot {
                    existing.likelySpot = likelySpot
                    didUpdate = true
                }
                if upsertBirdMarkLinks(
                    bird: existing,
                    markDataDTOs: birdDTO.fieldMarkData,
                    variantMap: variantMap,
                    context: context
                ) {
                    didUpdate = true
                }
                if didUpdate {
                    context.insert(existing)
                }
                continue
            }

            let bird = Bird(
                id: birdDTO.id,
                commonName: birdDTO.commonName,
                scientificName: birdDTO.scientificName,
                staticImageName: birdDTO.staticImageName,
                family: birdDTO.family,
                order_name: birdDTO.order_name,
                descriptionText: birdDTO.descriptionText,
                conservation_status: birdDTO.conservation_status,
                migration_strategy: nil,
                hemisphere: nil,
                validLocations: normalizedValidLocations,
                validMonths: birdDTO.validMonths,
                likelySpot: normalizedLikelySpot,
                shape_id: birdDTO.shape_id,
                size_category: birdDTO.size_category,
                shape: birdDTO.shape_id.flatMap { shapeMap[$0] }
            )
            _ = upsertBirdMarkLinks(
                bird: bird,
                markDataDTOs: birdDTO.fieldMarkData,
                variantMap: variantMap,
                context: context
            )

            context.insert(bird)
        }

        try context.save()
    }

    enum SeederError: Error {
        case fileNotFound
    }

    @discardableResult
    private func upsertBirdMarkLinks(
        bird: Bird,
        markDataDTOs: [BirdFieldMarkDataDTO]?,
        variantMap: [String: FieldMarkVariant],
        context: ModelContext
    ) -> Bool {
        guard let markDataDTOs, !markDataDTOs.isEmpty else { return false }

        var didChange = false
        var existingKeys = Set<String>()
        if let links = bird.fieldMarkLinks {
            for link in links {
                if let variantId = link.variant?.id {
                    existingKeys.insert("\(link.area.lowercased())|\(variantId.uuidString.lowercased())")
                }
            }
        }

        for dto in markDataDTOs {
            let variantKey = dto.variantId.lowercased()
            guard let variant = variantMap[variantKey] else { continue }
            let key = "\(dto.area.lowercased())|\(variant.id.uuidString.lowercased())"
            if existingKeys.contains(key) {
                continue
            }

            let link = BirdFieldMarkVariantLink(
                bird: bird,
                fieldMark: variant.fieldMark,
                variant: variant,
                area: dto.area
            )
            context.insert(link)
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

extension IdentificationSeeder {
    static let shared = IdentificationSeeder()
}
