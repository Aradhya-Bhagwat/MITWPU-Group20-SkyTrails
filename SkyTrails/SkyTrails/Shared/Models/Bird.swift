
import Foundation
import CoreLocation
import SwiftData

@Model
final class BirdFieldMarkVariantLink {
    @Attribute(.unique)
    var id: UUID

    var bird: Bird?
    var fieldMark: BirdFieldMark?
    var variant: FieldMarkVariant?
    var area: String

    init(
        id: UUID = UUID(),
        bird: Bird? = nil,
        fieldMark: BirdFieldMark? = nil,
        variant: FieldMarkVariant? = nil,
        area: String
    ) {
        self.id = id
        self.bird = bird
        self.fieldMark = fieldMark
        self.variant = variant
        self.area = area
    }
}

@Model
final class Bird {
    @Attribute(.unique)
    var id: UUID
    var commonName: String
    var scientificName: String
    var staticImageName: String
    var family: String?
    var order_name: String?
    var descriptionText: String?
    var conservation_status: String?
    
   
    var migration_strategy: String?
    var hemisphere: String?
   
    var validLocations: [String]?
    var validMonths: [Int]?
    var likelySpot: String?
    var shape_id: String?
    var size_category: Int?

    var shape: BirdShape?

    @Relationship(deleteRule: .cascade)
    var fieldMarkLinks: [BirdFieldMarkVariantLink]? = []
    @Relationship(deleteRule: .nullify, inverse: \IdentificationResult.bird)
    var identificationResults: [IdentificationResult]? = []
    @Relationship(deleteRule: .cascade, inverse: \IdentificationCandidate.bird)
    var identificationCandidates: [IdentificationCandidate]? = []
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
            likelySpot: String? = nil,
            shape_id: String? = nil,
            size_category: Int? = nil,
            shape: BirdShape? = nil
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
            self.likelySpot = likelySpot
            self.shape_id = shape_id
            self.size_category = size_category
            self.shape = shape
        }
}
