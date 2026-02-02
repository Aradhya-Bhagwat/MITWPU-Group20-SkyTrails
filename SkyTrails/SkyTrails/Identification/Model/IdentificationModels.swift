import Foundation
import CoreLocation
import SwiftData

struct BirdDatabase: Decodable {
    let metadata: Metadata
    let referenceData: ReferenceData
    var birds: [Bird]

    enum CodingKeys: String, CodingKey {
        case metadata
        case referenceData = "reference_data"
        case birds
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.metadata = try container.decode(Metadata.self, forKey: .metadata)
        self.referenceData = try container.decode(ReferenceData.self, forKey: .referenceData)
        let refBirds = try container.decode([ReferenceBird].self, forKey: .birds)
        self.birds = refBirds.map { Bird.fromReferenceBird($0) }
    }
}

struct Metadata: Decodable {
    let version: String
    let totalSpecies: Int
    let description: String?

    enum CodingKeys: String, CodingKey {
        case version
        case totalSpecies = "total_species"
        case description
    }
}


struct ReferenceData: Decodable {
    let shapes: [BirdShape]
    let fieldMarks: [ReferenceFieldMark]
    let locations: [String]
    let colors: [String]

    enum CodingKeys: String, CodingKey {
        case shapes
        case fieldMarks = "field_marks"
        case locations
        case colors
    }
}
struct ReferenceFieldMark: Codable {
    let area: String
    let variants: [String]
}

struct BirdShape: Codable {
    let id: String
    let name: String
    let icon: String
  
    let neck_variations: [NeckVariation]?
    
    var imageView: String { return icon }
}

struct NeckVariation: Codable {
    let id: String
    let head_offset_y: Int
}
struct ReferenceBird: Codable, Identifiable {
    let id: String
    let commonName: String
    let scientificName: String?
    let imageName: String
    let validLocations: [String]
    let validMonths: [Int]?
    let attributes: BirdAttributes
    let fieldMarks: [FieldMarkData]
    var isUserCreated: Bool? = false
    
    enum CodingKeys: String, CodingKey {
        case id, attributes, isUserCreated
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case imageName = "image_name"
        case validLocations = "valid_locations"
        case validMonths = "valid_months"
        case fieldMarks = "field_marks"
    }
}
struct IdentificationData {
    var date: String?
    var location: String?
    var size: String?
    var shape: String?
    var fieldMarks: [String]?
}

struct BirdAttributes: Codable {
    let shapeId: String
    let sizeCategory: Int
    let rarity: String
    
    enum CodingKeys: String, CodingKey {
        case shapeId = "shape_id"
        case sizeCategory = "size_category"
        case rarity
    }
}

struct FieldMarkData: Codable {
    let area: String
    let variant: String
    let colors: [String]
}

struct History: Codable {
    var imageView: String
    var specieName: String
    var date: String
}
enum FieldMarkCategory: String, Codable{
    case locationDate = "Location & Date"
    case size = "Size"
    case shape = "Shape"
    case fieldMarks = "Field Marks"
}

struct FieldMarkType: Codable {
    var symbols: String
    var fieldMarkName: FieldMarkCategory
    var isSelected: Bool? = false
}

struct ChooseFieldMark: Codable {
    var imageView: String
    var name: String
    var isSelected: Bool? = false
}

struct IdentificationBird: Codable, Identifiable {
    let id: String
    let name: String
    let scientificName: String
    let confidence: Double
    let description: String
    let imageName: String
    let scoreBreakdown: String
}

// Temporary Wrapper for Identification Results
struct IdentifiedBird {
    let bird: Bird
    var confidence: Double
    var scoreBreakdown: String
    
    // Proxy properties
    var id: UUID { bird.id }
    var commonName: String { bird.commonName }
    var scientificName: String { bird.scientificName }
    var staticImageName: String { bird.staticImageName }
    var validLocations: [String]? { bird.validLocations }
    var validMonths: [Int]? { bird.validMonths }
    var fieldMarks: [FieldMarkData]? { bird.fieldMarks }
    var rarityLevel: BirdRarityLevel? { bird.rarityLevel }
    var name: String { bird.commonName }
}