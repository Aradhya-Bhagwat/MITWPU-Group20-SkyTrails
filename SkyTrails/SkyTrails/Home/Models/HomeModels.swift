//
//  models.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import CoreLocation

// MARK: - 1. JSON LOADING HELPER
class DataLoader {
    static func load<T: Decodable>(_ filename: String, as type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("❌ File not found: \(filename).json")
            fatalError("Could not find file: \(filename).json")
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ Error parsing \(filename).json: \(error)")
            fatalError("Failed to parse \(filename).json: \(error.localizedDescription)")
        }
    }
}

// MARK: - 2. JSON RESPONSE WRAPPERS

// Wrapper for 'home_data.json'
struct CoreHomeData: Codable {
    let predicted_migrations: [PredictedMigration]?
    let watchlist_birds: [UpcomingBird]?
    let recommended_birds: [UpcomingBird]?
    let bird_categories: [BirdCategory]?
    let watchlist_spots: [PopularSpot]?
    let recommended_spots: [PopularSpot]?
    let dynamic_predictions: [DynamicCard]?
}

// Wrapper for 'community.json'
struct CommunityResponse: Codable {
    let community_observations: [CommunityObservation]?
}

// Wrapper for 'daily_news.json'
struct NewsResponse: Codable {
    let latest_news: [NewsItem]?
}

// MARK: - 3. MODEL STRUCTS

// --- News Models ---
struct NewsItem: Codable {
    let title: String
    let description: String
    let imageName: String
}

// --- Dynamic Map Card Models (Raw) ---
struct RawCoordinate: Codable {
    let lat: Double
    let lon: Double
}

struct RawHotspotPin: Codable {
    let lat: Double
    let lon: Double
    let bird_image_name: String
}

struct DynamicCard: Codable {
    let card_type: String
    
    // Migration Fields
    let bird_name: String?
    let bird_image_name: String?
    let start_location: String?
    let end_location: String?
    let current_progress: Float?
    let path_points: [RawCoordinate]?
    
    // Hotspot Fields
    let place_name: String?
    let species_count: Int?
    let place_image: String?
    let distance_string: String?
    let area_boundary: [RawCoordinate]?
    let hotspots: [RawHotspotPin]?
    
    let date_range: String?
}

// --- Clean Models for UI (Converted) ---

// Migration Card
struct MigrationPrediction {
    let birdName: String
    let birdImageName: String
    let startLocation: String
    let endLocation: String
    let dateRange: String
    let pathCoordinates: [CLLocationCoordinate2D]
    let currentProgress: Float
}

// Hotspot Sub-Model
struct BirdHotspot {
    let coordinate: CLLocationCoordinate2D
    let birdImageName: String
}

// Hotspot Card
struct HotspotPrediction {
    let placeName: String
    let placeImageName: String
    let speciesCount: Int
    let distanceString: String
    let dateRange: String
    let areaBoundary: [CLLocationCoordinate2D]
    let hotspots: [BirdHotspot]
}

enum MapCardType {
    case migration(MigrationPrediction)
    case hotspot(HotspotPrediction)
}

// --- Home Section Models ---

struct PredictedMigration: Codable {
    let title: String
    let subtitle: String
    let imageName: String
}

struct UpcomingBird: Codable {
    let imageName: String
    let title: String
    let date: String
}

struct BirdCategory: Codable {
    let icon: String
    let title: String
}

struct PopularSpot: Codable {
    let imageName: String
    let title: String
    let location: String
}

// --- Community Models ---

struct User: Codable {
    let name: String
    let observations: Int
    let profileImageName: String
    
    enum CodingKeys: String, CodingKey {
        case name, observations
        case profileImageName = "profile_image_name"
    }
}

struct CommunityObservation: Codable {
    let user: User
    let birdName: String
    let location: String
    let imageName: String
    
    enum CodingKeys: String, CodingKey {
        case user, location
        case birdName = "bird_name"
        case imageName = "image_name"
    }
}

// MARK: - 4. MAIN DATA MANAGER (HomeModels)

class HomeModels {
    
    // Data Arrays accessed by ViewController
    var predictedMigrations: [PredictedMigration] = []
    var watchlistBirds: [UpcomingBird] = []
    var recommendedBirds: [UpcomingBird] = []
    var birdCategories: [BirdCategory] = []
    var watchlistSpots: [PopularSpot] = []
    var recommendedSpots: [PopularSpot] = []
    var homeScreenSpots: [PopularSpot] {
            if watchlistSpots.isEmpty {
                return recommendedSpots
            } else {
                return watchlistSpots
            }
        }
    var homeScreenBirds: [UpcomingBird] {
            if watchlistBirds.isEmpty {
                return recommendedBirds
            } else {
                return watchlistBirds
            }
        }
    var latestNews: [NewsItem] = []
    var communityObservations: [CommunityObservation] = []
    
    // Private raw data for map cards
    private var dynamicCards: [DynamicCard] = []
    
    init() {
        loadAllData()
    }
    
    private func loadAllData() {
        // 1. Load Core Home Data (from home_data.json)
        let coreData = DataLoader.load("home_data", as: CoreHomeData.self)
        
        self.predictedMigrations = coreData.predicted_migrations ?? []
        self.watchlistBirds = coreData.watchlist_birds ?? []
        self.recommendedBirds = coreData.recommended_birds ?? []
        self.birdCategories = coreData.bird_categories ?? []
        self.watchlistSpots = coreData.watchlist_spots ?? []
        self.recommendedSpots = coreData.recommended_spots ?? []
        self.dynamicCards = coreData.dynamic_predictions ?? []
        
        // 2. Load Community Data (from community.json)
        let communityData = DataLoader.load("community", as: CommunityResponse.self)
        self.communityObservations = communityData.community_observations ?? []
        
        // 3. Load News Data (from daily_news.json)
        let newsData = DataLoader.load("daily_news", as: NewsResponse.self)
        self.latestNews = newsData.latest_news ?? []
    }
    
    // Logic to convert Raw JSON Map data into MapKit ready objects
    func getDynamicMapCards() -> [MapCardType] {
        return dynamicCards.compactMap { rawCard -> MapCardType? in
            
            // Utility to convert RawCoordinate array to CLLocationCoordinate2D array
            let coordConverter: ([RawCoordinate]) -> [CLLocationCoordinate2D] = { rawCoords in
                return rawCoords.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            }
            
            // --- MIGRATION CARD CONVERSION ---
            if rawCard.card_type == "migration" {
                guard let name = rawCard.bird_name,
                      let image = rawCard.bird_image_name,
                      let start = rawCard.start_location,
                      let end = rawCard.end_location,
                      let date = rawCard.date_range,
                      let progress = rawCard.current_progress,
                      let rawPoints = rawCard.path_points else {
                    return nil
                }
                
                let coords = coordConverter(rawPoints)
                
                let prediction = MigrationPrediction(
                    birdName: name,
                    birdImageName: image,
                    startLocation: start,
                    endLocation: end,
                    dateRange: date,
                    pathCoordinates: coords,
                    currentProgress: progress
                )
                return .migration(prediction)
            }
            
            // --- HOTSPOT CARD CONVERSION ---
            else if rawCard.card_type == "hotspot" {
                guard let name = rawCard.place_name,
                      let image = rawCard.place_image,
                      let count = rawCard.species_count,
                      let distance = rawCard.distance_string,
                      let date = rawCard.date_range,
                      let rawBoundary = rawCard.area_boundary,
                      let rawHotspots = rawCard.hotspots else {
                    return nil
                }
                
                let boundaryCoords = coordConverter(rawBoundary)
                
                let hotspotPins = rawHotspots.map { pin in
                    BirdHotspot(coordinate: CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lon),
                                birdImageName: pin.bird_image_name)
                }
                
                let prediction = HotspotPrediction(
                    placeName: name,
                    placeImageName: image,
                    speciesCount: count,
                    distanceString: distance,
                    dateRange: date,
                    areaBoundary: boundaryCoords,
                    hotspots: hotspotPins
                )
                return .hotspot(prediction)
            }
            
            return nil
        }
    }
}

// MARK: - 5. UTILITIES (Renamed to avoid conflicts)

extension Array where Element == CLLocationCoordinate2D {
    
    /// Generates a series of intermediate coordinates to smooth the path corners.
    func generateSmoothedPath(tension: Double = 0.5, resolution: Int = 16) -> [CLLocationCoordinate2D] {
        guard self.count > 2 else { return self }
        
        var smoothedCoords: [CLLocationCoordinate2D] = []
        
        for i in 0..<(self.count) {
            let p1 = self[i]
            let p2 = self[(i + 1) % self.count] // Wraps around for a closed shape
            
            smoothedCoords.append(p1)
            
            for j in 1..<resolution {
                let t = Double(j) / Double(resolution)
                
                let lat = p1.latitude + (p2.latitude - p1.latitude) * t
                let lon = p1.longitude + (p2.longitude - p1.longitude) * t
                
                smoothedCoords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return smoothedCoords
    }
    
    // Renamed helper to calculate total length
    func calculateTotalLength() -> Double {
        guard self.count > 1 else { return 0 }
        var totalLength: Double = 0
        for i in 0..<(self.count - 1) {
            let coord1 = self[i]
            let coord2 = self[i+1]
            let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            totalLength += location1.distance(from: location2)
        }
        return totalLength
    }
    
    // ⭐️ RENAMED: Use 'calculateProgressCoordinates' to fix redeclaration error
    func calculateProgressCoordinates(at percentage: Double) -> (progressCoords: [CLLocationCoordinate2D], currentCoord: CLLocationCoordinate2D) {
        
        guard self.count > 1 else {
            if let singleCoord = self.first { return ([singleCoord], singleCoord) }
            return ([], CLLocationCoordinate2D())
        }
        
        let boundedPercentage = Swift.min(1.0, Swift.max(0.0, percentage))
        let totalPathLength = self.calculateTotalLength() // Use renamed function
        let targetDistance = boundedPercentage * totalPathLength
        
        var currentDistance: Double = 0
        var segmentCoords: [CLLocationCoordinate2D] = [self.first!]
        
        if boundedPercentage >= 1.0 { return (self, self.last!) }
        
        for i in 0..<(self.count - 1) {
            let startCoord = self[i]
            let endCoord = self[i+1]
            
            let segmentLength = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
                .distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
            
            if (currentDistance + segmentLength) >= targetDistance {
                let remainingDistanceInSegment = targetDistance - currentDistance
                let ratio = remainingDistanceInSegment / segmentLength
                
                let interpolatedLatitude = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * ratio
                let interpolatedLongitude = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * ratio
                
                let interpolatedCoord = CLLocationCoordinate2D(latitude: interpolatedLatitude, longitude: interpolatedLongitude)
                segmentCoords.append(interpolatedCoord)
                
                return (segmentCoords, interpolatedCoord)
            }
            
            currentDistance += segmentLength
            segmentCoords.append(endCoord)
        }
        return (self, self.last ?? CLLocationCoordinate2D())
    }
}
