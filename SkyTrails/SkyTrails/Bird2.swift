//
//  Bird2.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - Bird Enums

enum BirdRarityLevel: String, Codable {
    case common
    case uncommon
    case rare
    case very_rare
    case endangered
}

// MARK: - Bird Model (Reference Data)

@Model
final class Bird {
    @Attribute(.unique) var id: UUID
    var commonName: String
    var scientificName: String
    var staticImageName: String
    
    // Taxonomy & Details
    var family: String?
    var order_name: String?
    var descriptionText: String? // 'description' in schema
    var conservation_status: String?
    
    // Identification Keys
    var shapeId: String? // shape_id in schema
    var sizeCategory: Int?
    var rarityLevel: BirdRarityLevel?
    
    // Geography & Migration
    var migration_strategy: String?
    var hemisphere: String?
    
    // Legacy/Compatibility Fields (Optional, kept for seeding/identification)
    var validLocations: [String]?
    var validMonths: [Int]?
    var fieldMarks: [FieldMarkData]? // Struct from Identification
    
    // Relationships
    // The schema defines relationships:
    // Ref: Bird.id < WatchlistEntry.bird_id
    // Explicitly defining inverse to help SwiftData schema generation
    @Relationship(deleteRule: .cascade, inverse: \WatchlistEntry.bird) var watchlistEntries: [WatchlistEntry]?

    var name: String { return commonName } // Compatibility alias

    init(
        id: UUID = UUID(),
        commonName: String,
        scientificName: String,
        staticImageName: String,
        family: String? = nil,
        order_name: String? = nil,
        descriptionText: String? = nil,
        conservation_status: String? = nil,
        shapeId: String? = nil,
        sizeCategory: Int? = nil,
        rarityLevel: BirdRarityLevel? = nil,
        migration_strategy: String? = nil,
        hemisphere: String? = nil,
        validLocations: [String]? = nil,
        validMonths: [Int]? = nil,
        fieldMarks: [FieldMarkData]? = nil
    ) {
        self.id = id
        self.commonName = commonName
        self.scientificName = scientificName
        self.staticImageName = staticImageName
        self.family = family
        self.order_name = order_name
        self.descriptionText = descriptionText
        self.conservation_status = conservation_status
        self.shapeId = shapeId
        self.sizeCategory = sizeCategory
        self.rarityLevel = rarityLevel
        self.migration_strategy = migration_strategy
        self.hemisphere = hemisphere
        self.validLocations = validLocations
        self.validMonths = validMonths
        self.fieldMarks = fieldMarks
    }
    
    // MARK: - Factory Methods
    
    static func fromSpotBird(_ spotBird: SpotBird) -> Bird {
        return Bird(
            id: UUID(),
            commonName: spotBird.name,
            scientificName: "",
            staticImageName: spotBird.imageName
        )
    }
    
    static func fromReferenceBird(_ refBird: ReferenceBird) -> Bird {
        // Map old rarity string to new Enum
        let rarityString = refBird.attributes.rarity.lowercased()
        let rarity: BirdRarityLevel
        switch rarityString {
        case "common": rarity = .common
        case "rare": rarity = .rare
        default: rarity = .uncommon
        }
        
        return Bird(
            id: UUID(uuidString: refBird.id) ?? UUID(),
            commonName: refBird.commonName,
            scientificName: refBird.scientificName ?? "",
            staticImageName: refBird.imageName,
            shapeId: refBird.attributes.shapeId,
            sizeCategory: refBird.attributes.sizeCategory,
            rarityLevel: rarity,
            validLocations: refBird.validLocations,
            validMonths: refBird.validMonths,
            fieldMarks: refBird.fieldMarks
        )
    }
}

