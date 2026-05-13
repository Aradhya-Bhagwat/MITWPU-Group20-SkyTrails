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

// MARK: - New Location Prediction Models

struct LocationPredictionResponse: Codable {
    let found: Bool
    let lat: Double
    let lng: Double
    let radiusKm: Double
    let gridId: String
    let weekNumbers: [Int]
    let hotspots: [PredictedHotspot]
    let weeklyResults: [String: WeeklyPredictionResult]
    let mergedSpecies: [PredictedSpecies]
    let meta: PredictionMeta
}

struct PredictedHotspot: Codable {
    let hotspotGeoId: String?
    let ebirdHotspotId: String?
    let name: String?
    let locality: String?
    let lat: Double
    let lng: Double
    let distanceKm: Double
    let tag: String // "closest", "farthest", "within_radius"
}

struct WeeklyPredictionResult: Codable {
    let week: Int
    let speciesCount: Int
    let regionalTrendsCount: Int
    let hotspotSpeciesCount: Int
    let ebirdRecentCount: Int?
    let species: [PredictedSpecies]
}

struct PredictedSpecies: Codable {
    let ebirdSpeciesCode: String
    let commonName: String
    let scientificName: String?
    let imageName: String?
    let probability: Int
    let residencyStatus: String
    let sources: [String]
    let spotNames: [String]
    let peakWeek: Int?
    let weekScores: [String: Int]?
}

struct PredictionMeta: Codable {
    let hotspotsFound: Int
    let hotspotsQueried: Int?
    let hotspotsFromEbird: Int?
    let ebirdRecentSpecies: Int?
    let weeksQueried: Int
    let totalSpecies: Int
}

// MARK: - Weekly Trends Models

struct WeeklyTrendsResponse: Codable {
    let found: Bool
    let lat: Double
    let lng: Double
    let gridId: String
    let weekNumbers: [Int]
    let weeklyBreakdown: [String: WeeklyBreakdownEntry]
    let unifiedSpecies: [UnifiedSpeciesEntry]
    let meta: WeeklyTrendsMeta
}

struct WeeklyBreakdownEntry: Codable {
    let week: Int
    let speciesCount: Int
    let species: [WeeklySpeciesEntry]
}

struct WeeklySpeciesEntry: Codable {
    let ebirdSpeciesCode: String
    let commonName: String
    let score: Double
    let sightabilityPercent: Int
    let hits: Int
    let max: Double
}

struct UnifiedSpeciesEntry: Codable {
    let ebirdSpeciesCode: String
    let commonName: String
    let weekScores: [String: Int]
    let peakPercent: Int
    let peakWeek: Int
}

struct WeeklyTrendsMeta: Codable {
    let weeksQueried: Int
    let weeksWithData: Int
    let totalUniqueSpecies: Int
}
