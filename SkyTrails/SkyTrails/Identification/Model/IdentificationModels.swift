
import Foundation
import CoreLocation

struct BirdDatabase: Codable {
    var birds: [Bird2]
    let reference_data: ReferenceData
    
    enum CodingKeys: String, CodingKey {
        case birds
        case reference_data
    }
}

struct ReferenceData: Codable {
    let shapes: [BirdShape]
    let fieldMarks: [ReferenceFieldMark]
    
    enum CodingKeys: String, CodingKey {
        case shapes
        case fieldMarks = "field_marks"
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

