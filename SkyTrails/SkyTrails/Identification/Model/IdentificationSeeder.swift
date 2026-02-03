import Foundation
import SwiftData

struct IdentificationSeeder {

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

    @MainActor
    static func seed(context: ModelContext) throws {

        // Prevent duplicate seeding
        let birdCount = try context.fetchCount(FetchDescriptor<Bird>())
        guard birdCount == 0 else { return }

        guard let url = Bundle.main.url(
            forResource: "bird_database",
            withExtension: "json"
        ) else {
            throw SeederError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let db = try JSONDecoder().decode(BirdDB.self, from: data)

        // MARK: - Step 1: Create Shapes
        var shapeMap: [String: BirdShape] = [:]
        
        for shapeDTO in db.reference_data.shapes {
            let shape = BirdShape(
                id: shapeDTO.id,
                name: shapeDTO.name,
                icon: shapeDTO.icon
            )
            context.insert(shape)
            shapeMap[shapeDTO.id] = shape
        }

        // MARK: - Step 2: Create Field Marks
        var fieldMarkMap: [String: BirdFieldMark] = [:]
        
        for fieldMarkDTO in db.reference_data.fieldMarks {
            let fieldMark = BirdFieldMark(area: fieldMarkDTO.area)
            fieldMark.id = UUID(uuidString: fieldMarkDTO.id) ?? UUID()
            
            // Link to shape
            if let shape = shapeMap[fieldMarkDTO.shapeId] {
                fieldMark.shape = shape
            }
            
            context.insert(fieldMark)
            fieldMarkMap[fieldMarkDTO.id] = fieldMark
        }

        // MARK: - Step 3: Create Variants
        var variantMap: [String: FieldMarkVariant] = [:]
        
        for variantDTO in db.reference_data.variants {
            let variant = FieldMarkVariant(name: variantDTO.name)
            variant.id = UUID(uuidString: variantDTO.id) ?? UUID()
            
            // Link to field mark
            if let fieldMark = fieldMarkMap[variantDTO.fieldMarkId] {
                variant.fieldMark = fieldMark
            }
            
            context.insert(variant)
            variantMap[variantDTO.id] = variant
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
