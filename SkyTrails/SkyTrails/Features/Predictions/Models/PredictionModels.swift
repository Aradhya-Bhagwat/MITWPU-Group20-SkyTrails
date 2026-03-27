import Foundation

enum ResidencyStatus: String, Codable {
    case recentlySpotted = "Recently spotted"
    case present = "Present"
    case migrating = "Migrating"
    case statusAndTrends = "Status and Trends" // Added to support R script source
}

struct PredictionResponse: Codable {
    let card: Hotspot
    let nearbyHotspots: [Hotspot]
}

struct Hotspot: Codable, Identifiable {
    var id: String { hotspotId }
    let hotspotId: String
    let placeName: String
    let locationDetail: String
    let speciesCount: Int
    let distanceKm: Double
    let distanceString: String
    let center: Coordinates
    let species: [Species]?
    let weekNumber: String
}

struct Coordinates: Codable {
    let lat: Double
    let lng: Double
}

struct Species: Codable, Identifiable {
    var id: String { ebirdSpeciesCode ?? UUID().uuidString }
    let birdId: String?
    let ebirdSpeciesCode: String?
    let commonName: String
    let scientificName: String?
    let imageName: String?
    let probability: Int
    let weekNumberValue: Int?
    let weekNumber: String
    let residencyStatus: ResidencyStatus
}
