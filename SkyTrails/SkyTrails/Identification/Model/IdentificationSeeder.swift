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
    }

    private struct ShapeDTO: Codable {
        let id: String
        let name: String
        let icon: String
        let fieldMarks: [ShapeFieldMarkDTO]?
    }
    
    private struct ShapeFieldMarkDTO: Codable {
        let id: String
        let area: String
        let variants: [VariantDTO]
    }
    
    private struct VariantDTO: Codable {
        let id: String
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

        // MARK: - Seed Shapes with Field Marks and Variants
        var shapeMap: [String: BirdShape] = [:]
        var variantMap: [String: FieldMarkVariant] = [:] // UUID string -> FieldMarkVariant

        for s in db.reference_data.shapes {
            let shape = BirdShape(
                id: s.id,
                name: s.name,
                icon: s.icon
            )
            context.insert(shape)
            shapeMap[s.id] = shape
            
            // Seed field marks for this shape
            if let fieldMarks = s.fieldMarks {
                for fm in fieldMarks {
                    // Create BirdFieldMark with proper UUID
                    let fieldMark = BirdFieldMark(area: fm.area)
                    fieldMark.id = UUID(uuidString: fm.id) ?? UUID()
                    fieldMark.shape = shape
                    context.insert(fieldMark)
                    
                    // Create variants for this field mark
                    for v in fm.variants {
                        let variant = FieldMarkVariant(name: v.name)
                        variant.id = UUID(uuidString: v.id) ?? UUID()
                        variant.fieldMark = fieldMark
                        context.insert(variant)
                        
                        // Store in map for bird seeding
                        variantMap[v.id] = variant
                    }
                }
            }
        }

        // MARK: - Seed Birds
        for b in db.birds {

            let rarity = BirdRarityLevel(
                rawValue: b.rarityLevel?.lowercased() ?? "common"
            ) ?? .common

            // Convert BirdFieldMarkDataDTO to BirdFieldMarkData
            var fieldMarkData: [BirdFieldMarkData] = []
            if let markDataDTOs = b.fieldMarkData {
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
                id: b.id,
                commonName: b.commonName,
                scientificName: b.scientificName,
                staticImageName: b.staticImageName,
                family: b.family,
                order_name: b.order_name,
                descriptionText: b.descriptionText,
                conservation_status: b.conservation_status,
                rarityLevel: rarity,
                migration_strategy: nil,
                hemisphere: nil,
                validLocations: b.validLocations,
                validMonths: b.validMonths,
                shape_id: b.shape_id,
                size_category: b.size_category
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
