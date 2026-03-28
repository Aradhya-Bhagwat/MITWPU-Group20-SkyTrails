
import Foundation
import CoreLocation
import SwiftData

struct BirdCategory: Codable, Hashable {
    let icon: String
    let title: String
}

struct NewsItem: Codable, Hashable {
    let title: String
    let summary: String
    let link: String
    let imageName: String
    let sourceName: String?
    let publishedAt: String?
}

struct UpcomingBird: Codable, Hashable {
    let imageName: String
    let title: String
    let date: String
}

struct PopularSpot: Codable, Hashable {
    let id: UUID
    let imageName: String
    let title: String
    let location: String
    let latitude: Double?
    let longitude: Double?
    let speciesCount: Int
    let radius: Double?
}

struct HomeScreenData {
    let upcomingBirds: [UpcomingBirdResult]
    let myWatchlistBirds: [UpcomingBirdResult]
    let recommendedBirds: [RecommendedBirdResult]
    let watchlistSpots: [PopularSpotResult]
    let recommendedSpots: [PopularSpotResult]
    let migrationCards: [DynamicMapCard]
    let recentObservations: [CommunityObservation]
    let birdCategories: [BirdCategory]
    let news: [NewsItem]
    let errorMessage: String?
    
    var displayableUpcomingBirds: [UpcomingBirdUI] {
        let watchlistUI = myWatchlistBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.statusText
            )
        }
        let recommendedUI = recommendedBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.dateRange
            )
        }
        var combinedBirds: [UpcomingBirdUI] = []
        combinedBirds.append(contentsOf: watchlistUI.prefix(6))
        
        let remainingSlots = 6 - combinedBirds.count
        if remainingSlots > 0 {
            let watchlistBirdNames = Set(watchlistUI.map { $0.title })
            let uniqueRecommended = recommendedUI.filter { !watchlistBirdNames.contains($0.title) }
            combinedBirds.append(contentsOf: uniqueRecommended.prefix(remainingSlots))
        }
        
        return combinedBirds
    }
    
    var displayableSpots: [PopularSpotUI] {
        let sourceSpots = recommendedSpots.isEmpty ? watchlistSpots : recommendedSpots
        return sourceSpots.map { spot in
            PopularSpotUI(
                id: spot.id,
                imageName: spot.imageName ?? "placeholder_image",
                title: spot.title,
                location: spot.location,
                latitude: spot.latitude,
                longitude: spot.longitude,
                speciesCount: spot.speciesCount,
                radius: spot.radius,
                edgeSpecies: spot.edgeSpecies
            )
        }
    }
}

struct RecommendedBirdResult: Identifiable {
    let id = UUID()
    let bird: Bird
    let dateRange: String
}

struct PopularSpotResult: Identifiable {
    let id: UUID
    let title: String
    let location: String
    let latitude: Double
    let longitude: Double
    let speciesCount: Int
    let observedCount: Int
    let radius: Double
    let imageName: String?
    let edgeSpecies: [NearbyHotspotEdgeSpecies]?
    var distanceKm: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MigrationCardResult: Identifiable {
    let id = UUID()
    let bird: Bird
    let session: MigrationSession
    let currentPosition: CLLocationCoordinate2D?
    let progress: Float
    let paths: [TrajectoryPath]
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var startComponents = DateComponents()
        startComponents.weekOfYear = session.startWeek
        startComponents.yearForWeekOfYear = currentYear
        startComponents.weekday = 2
        
        var endComponents = DateComponents()
        endComponents.weekOfYear = session.endWeek
        endComponents.yearForWeekOfYear = currentYear
        endComponents.weekday = 2
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return "Week \(session.startWeek) - \(session.endWeek)"
    }
}

struct MigrationTrajectoryResult {
    let session: MigrationSession
    let pathsAtWeek: [TrajectoryPath]
    let requestedWeek: Int
    var mostLikelyPosition: CLLocationCoordinate2D?
}

struct PredictionInputData {
    var id: UUID = UUID()
    var locationName: String?
    var locationDetail: String?
    var latitude: Double?
    var longitude: Double?
    var startDate: Date? = Date()
    var endDate: Date? = Date()
    var areaValue: Int = 2
    
    var weekRange: (start: Int, end: Int)? {
        guard let start = startDate, let end = endDate else { return nil }
        
        let startWeek = start.weekOfYear
        let endWeek = end.weekOfYear
        
        if startWeek > endWeek {
            return (start: startWeek, end: endWeek + 52)
        }
        return (start: startWeek, end: endWeek)
    }
}

struct FinalPredictionResult: Hashable {
    let birdName: String
    let imageName: String
    let likelySpot: String
    let matchedInputIndex: Int
    let matchedLocation: (lat: Double, lon: Double)
    let spottingProbability: Int
    let weekNumber: String?
    let residencyStatus: String?
    let ebirdSpeciesCode: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(birdName)
        hasher.combine(ebirdSpeciesCode)
        hasher.combine(matchedInputIndex)
        hasher.combine(matchedLocation.lat)
        hasher.combine(matchedLocation.lon)
    }
    
    static func == (lhs: FinalPredictionResult, rhs: FinalPredictionResult) -> Bool {
        return lhs.birdName == rhs.birdName &&
               lhs.ebirdSpeciesCode == rhs.ebirdSpeciesCode &&
               lhs.matchedInputIndex == rhs.matchedInputIndex &&
               lhs.matchedLocation.lat == rhs.matchedLocation.lat &&
               lhs.matchedLocation.lon == rhs.matchedLocation.lon
    }
}

enum DynamicMapCard {
    case combined(migration: MigrationPrediction, hotspot: HotspotPrediction)
}

struct MigrationPrediction {
    let birdName: String
    let birdImageName: String
    let startLocation: String
    let endLocation: String
    let currentProgress: Float
    let dateRange: String
    let pathCoordinates: [CLLocationCoordinate2D]
}

struct HotspotPrediction {
    let placeName: String
    let locationDetail: String
    let weekNumber: String
    let speciesCount: Int
    let distanceString: String
    let dateRange: String
    let placeImageName: String
    let terrainTag: String
    let seasonTag: String
    let centerCoordinate: CLLocationCoordinate2D
    let pinRadiusKm: Double
    let areaOverlay: HotspotAreaOverlay
    let hotspots: [HotspotBirdSpot]
    let birdSpecies: [BirdSpeciesDisplay]
}

enum HotspotAreaOverlay {
    case polygon(coordinates: [CLLocationCoordinate2D])
    case circle(radiusKm: Double)
}

struct BirdSpeciesDisplay: Hashable {
    let birdName: String
    let birdImageName: String
    let statusBadge: StatusBadge
    let sightabilityPercent: Int
    let weekNumber: String?
    let residencyStatus: String?
    
    struct StatusBadge: Hashable {
        let title: String
        let subtitle: String
        let iconName: String
        let backgroundColorName: String
    }
}

struct HotspotBirdSpot {
    let coordinate: CLLocationCoordinate2D
    let birdImageName: String
}

struct RelevantSighting {
    let lat: Double
    let lon: Double
    let week: Int
}

struct NearbyHotspotEdgeRequest: Encodable {
    let lat: Double
    let lng: Double
}

struct NearbyHotspotEdgeResponse: Codable {
    let card: NearbyHotspotEdgeCard?
    let nearbyHotspots: [NearbyHotspotEdgeCard]?
    let meta: NearbyHotspotEdgeMeta?
}

struct NearbyHotspotEdgeCard: Codable {
    let hotspotId: String
    let placeName: String
    let locationDetail: String
    let weekNumber: String?
    let speciesCount: Int?
    let distanceKm: Double?
    let distanceString: String?
    let center: NearbyHotspotEdgeCenter
    let species: [NearbyHotspotEdgeSpecies]?
}

struct NearbyHotspotEdgeCenter: Codable {
    let lat: Double
    let lng: Double
}

struct NearbyHotspotEdgeSpecies: Codable {
    let commonName: String
    let scientificName: String?
    let imageName: String?
    let probability: Int?
    let weekNumber: String?
    let residencyStatus: String?
}

struct NearbyHotspotEdgeMeta: Codable {
    let hotspotCacheHit: Bool
    let ebirdCacheUsed: Bool
}

extension Date {
    var weekOfYear: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: self)
    }
}
struct UpcomingBirdUI {
    let imageName: String
    let title: String
    let date: String
}

struct PopularSpotUI {
    let id: UUID
    let imageName: String
    let title: String
    let location: String
    let latitude: Double
    let longitude: Double
    let speciesCount: Int
    let radius: Double
    let edgeSpecies: [NearbyHotspotEdgeSpecies]?
}
