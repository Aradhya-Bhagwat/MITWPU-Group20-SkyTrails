import Foundation

enum ResidencyStatus: String, Codable {
    case recentlySpotted = "Recently spotted"
    case present = "Present"
    case migrating = "Migrating"
    case statusAndTrends = "Status and Trends"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ResidencyStatus(rawValue: rawValue) ?? .unknown
    }
}

struct HotspotPredictionResponse: Codable {
    let card: HotspotModel? 
    let nearbyHotspots: [HotspotModel]
}

struct HotspotModel: Codable, Identifiable {
    var id: String { hotspotId }
    let hotspotId: String
    let placeName: String
    let locationDetail: String
    let speciesCount: Int
    let distanceKm: Double
    let distanceString: String
    let center: HotspotCoordinates
    let species: [SpeciesModel]?
    let weekNumber: String? 
}

struct HotspotCoordinates: Codable {
    let lat: Double
    let lng: Double
}

struct SpeciesModel: Codable, Identifiable {
    var id: String { ebirdSpeciesCode ?? UUID().uuidString }
    let birdId: String?
    let ebirdSpeciesCode: String?
    let commonName: String
    let scientificName: String?
    let imageName: String?
    let likelihood: Int 
    let weekNumberValue: Int?
    let weekNumber: String? 
    let residencyStatus: ResidencyStatus
    
    enum CodingKeys: String, CodingKey {
        case birdId = "bird_id"
        case ebirdSpeciesCode = "ebird_species_code"
        case commonName = "commonName"
        case scientificName = "scientificName"
        case imageName = "imageName"
        case likelihood = "probability"
        case weekNumberValue = "weekNumberValue"
        case weekNumber = "weekNumber"
        case residencyStatus = "residencyStatus"
    }
}
