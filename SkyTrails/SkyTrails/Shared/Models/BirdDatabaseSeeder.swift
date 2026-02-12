//
//  BirdDatabaseSeeder.swift
//  SkyTrails
//
//  Seeds Bird entities from bird_database.json
//

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

    enum SeederError: Error {
        case fileNotFound
        case dataCorrupted
        case decodingFailed(Error)
    }

    func seed(modelContext: ModelContext) throws {
        let hasSeededKey = "kBirdDatabaseSeeded_v1"
        if UserDefaults.standard.bool(forKey: hasSeededKey) {
            print("ℹ️ [BirdDatabaseSeeder] Bird database already seeded. Skipping.")
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
        var existingBirdMap = Dictionary(uniqueKeysWithValues: existingBirds.map { ($0.id, $0) })

        for birdDTO in payload.birds {
            let rarity = BirdRarityLevel(
                rawValue: birdDTO.rarityLevel?.lowercased() ?? "common"
            ) ?? .common

            var fieldMarks: [BirdFieldMarkData] = []
            if let markDTOs = birdDTO.fieldMarkData {
                for mark in markDTOs {
                    if let variantUUID = UUID(uuidString: mark.variantId) {
                        fieldMarks.append(BirdFieldMarkData(area: mark.area, variantId: variantUUID))
                    }
                }
            }

            if let existing = existingBirdMap[birdDTO.id] {
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
                if existing.rarityLevel == nil {
                    existing.rarityLevel = rarity
                    didUpdate = true
                }
                if (existing.validLocations == nil || existing.validLocations?.isEmpty == true),
                   let validLocations = birdDTO.validLocations {
                    existing.validLocations = validLocations
                    didUpdate = true
                }
                if (existing.validMonths == nil || existing.validMonths?.isEmpty == true),
                   let validMonths = birdDTO.validMonths {
                    existing.validMonths = validMonths
                    didUpdate = true
                }
                if existing.shape_id == nil, let shapeId = birdDTO.shape_id {
                    existing.shape_id = shapeId
                    didUpdate = true
                }
                if existing.size_category == nil, let sizeCategory = birdDTO.size_category {
                    existing.size_category = sizeCategory
                    didUpdate = true
                }
                if (existing.fieldMarkData == nil || existing.fieldMarkData?.isEmpty == true),
                   !fieldMarks.isEmpty {
                    existing.fieldMarkData = fieldMarks
                    didUpdate = true
                }

                if didUpdate {
                    modelContext.insert(existing)
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
            bird.fieldMarkData = fieldMarks.isEmpty ? nil : fieldMarks
            modelContext.insert(bird)
            existingBirdMap[bird.id] = bird
        }

        try modelContext.save()
        UserDefaults.standard.set(true, forKey: hasSeededKey)
        print("✅ [BirdDatabaseSeeder] Seeded \(payload.birds.count) birds from bird_database.json")
    }
}
