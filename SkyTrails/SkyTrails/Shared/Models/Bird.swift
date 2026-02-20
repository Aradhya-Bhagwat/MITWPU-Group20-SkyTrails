//
//  Bird.swift
//  SkyTrails
//

import Foundation
import CoreLocation
import SwiftData

struct BirdFieldMarkData: Codable, Hashable {
    var area: String
    var variantId: UUID
}

@Model
final class Bird {
    @Attribute(.unique)
    var id: UUID
    var commonName: String
    var scientificName: String
    var staticImageName: String
    
    // Taxonomy & Details
    var family: String?
    var order_name: String?
    var descriptionText: String? // 'description' in schema
    var conservation_status: String?
    
   
    var migration_strategy: String?
    var hemisphere: String?
   
    var validLocations: [String]?
    var validMonths: [Int]?
    var shape_id: String?
    var size_category: Int?
    // In Bird.swift
    var fieldMarkData: [BirdFieldMarkData]? = []
    
    // MARK: - Relationships
    
    // Identification
    @Relationship(deleteRule: .nullify, inverse: \IdentificationResult.bird)
    var identificationResults: [IdentificationResult]? = []
    @Relationship(deleteRule: .cascade, inverse: \IdentificationCandidate.bird)
    var identificationCandidates: [IdentificationCandidate]? = []
    
    // Migration (Historical runs)
    @Relationship(deleteRule: .cascade, inverse: \MigrationSession.bird)
    var migrationSessions: [MigrationSession]? = []
    
    // Hotspots (Using Join Model for seasonality)
    @Relationship(deleteRule: .cascade, inverse: \HotspotSpeciesPresence.bird)
    var hotspotPresence: [HotspotSpeciesPresence]? = []
    
    // Watchlist Integration (NEW)
    // .nullify means: if bird is deleted, entries stay but bird reference becomes nil
    // This prevents deleting bird from deleting all watchlist entries
    @Relationship(deleteRule: .nullify, inverse: \WatchlistEntry.bird)
    var watchlistEntries: [WatchlistEntry]? = []
  
    var name: String { return commonName }

    init(
            id: UUID = UUID(),
            commonName: String,
            scientificName: String,
            staticImageName: String,
            family: String? = nil,
            order_name: String? = nil,
            descriptionText: String? = nil,
            conservation_status: String? = nil,
            migration_strategy: String? = nil,
            hemisphere: String? = nil,
            validLocations: [String]? = nil,
            validMonths: [Int]? = nil,
            shape_id: String? = nil,
            size_category: Int? = nil
        ) {
            self.id = id
            self.commonName = commonName
            self.scientificName = scientificName
            self.staticImageName = staticImageName
            self.family = family
            self.order_name = order_name
            self.descriptionText = descriptionText
            self.conservation_status = conservation_status
            self.migration_strategy = migration_strategy
            self.hemisphere = hemisphere
            self.validLocations = validLocations
            self.validMonths = validMonths
            self.shape_id = shape_id
            self.size_category = size_category
        }
}
