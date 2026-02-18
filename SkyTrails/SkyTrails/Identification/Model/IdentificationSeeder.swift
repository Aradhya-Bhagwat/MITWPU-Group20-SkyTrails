import Foundation
import SwiftData

@MainActor
final class IdentificationSeeder {

    // MARK: - DTOs (JSON → Swift)

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
        let rarityLevel: String?
        let validLocations: [String]?
        let validMonths: [Int]?
        let shape_id: String?
        let size_category: Int?
        let fieldMarkData: [BirdFieldMarkDataDTO]?
    }

    private struct BirdFieldMarkDataDTO: Codable {
        let area: String
        let variantId: String
    }

    // MARK: - Seeder Entry

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
                bird.shape_id != nil && bird.size_category != nil
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

        // MARK: - Step 1: Create Shapes
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

        // MARK: - Step 2: Create Field Marks
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
            
            // Link to shape
            if let shape = shapeMap[fieldMarkDTO.shapeId] {
                fieldMark.shape = shape
            }
            
            context.insert(fieldMark)
            fieldMarkMap[fieldMarkKey] = fieldMark
        }

        // MARK: - Step 3: Create Variants
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
            
            // Link to field mark
            if let fieldMark = fieldMarkMap[variantDTO.fieldMarkId.lowercased()] {
                variant.fieldMark = fieldMark
            }
            
            context.insert(variant)
            variantMap[variantKey] = variant
        }

        // MARK: - Step 4: Create Birds
        for birdDTO in db.birds {
            let rarity = BirdRarityLevel(
                rawValue: birdDTO.rarityLevel?.lowercased() ?? "common"
            ) ?? .common

            // Convert BirdFieldMarkDataDTO to BirdFieldMarkData
            var fieldMarkData: [BirdFieldMarkData] = []
            if let markDataDTOs = birdDTO.fieldMarkData {
                for dto in markDataDTOs {
                    if let variantUUID = UUID(uuidString: dto.variantId) {
                        let data = BirdFieldMarkData(
                            area: dto.area,
                            variantId: variantUUID
                        )
                        fieldMarkData.append(data)
                    }
                }
            }

            if let existing = existingBirdMap[birdDTO.id] {
                var didUpdate = false
                if existing.shape_id == nil, let shapeId = birdDTO.shape_id {
                    existing.shape_id = shapeId
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
                if (existing.fieldMarkData == nil || existing.fieldMarkData?.isEmpty == true),
                   !fieldMarkData.isEmpty {
                    existing.fieldMarkData = fieldMarkData
                    didUpdate = true
                }
                if existing.rarityLevel == nil {
                    existing.rarityLevel = rarity
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
                rarityLevel: rarity,
                migration_strategy: nil,
                hemisphere: nil,
                validLocations: birdDTO.validLocations,
                validMonths: birdDTO.validMonths,
                shape_id: birdDTO.shape_id,
                size_category: birdDTO.size_category
            )
            
            // Assign field mark data
            bird.fieldMarkData = fieldMarkData.isEmpty ? nil : fieldMarkData

            context.insert(bird)
        }

        try context.save()
    }

    enum SeederError: Error {
        case fileNotFound
    }
}

extension IdentificationSeeder {
    static let shared = IdentificationSeeder()
}
