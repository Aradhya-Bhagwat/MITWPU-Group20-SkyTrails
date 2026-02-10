//
//  HomeManager.swift
//  SkyTrails
//
//  Migrated to SwiftData Integration
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
class HomeManager {
    
    static let shared = HomeManager()
    
    private let modelContext: ModelContext
    private let watchlistManager: WatchlistManager
    private let hotspotManager: HotspotManager
    private let migrationManager: MigrationManager
    private let observationManager: CommunityObservationManager
    
    // Cache for performance
    var spotSpeciesCountCache: [String: Int] = [:]
    
    private init() {
        // Use WatchlistManager's shared context
        self.modelContext = WatchlistManager.shared.context
        self.watchlistManager = WatchlistManager.shared
        self.hotspotManager = HotspotManager(modelContext: modelContext)
        self.migrationManager = MigrationManager(modelContext: modelContext)
        self.observationManager = CommunityObservationManager(modelContext: modelContext)
    }
    
    // MARK: - Upcoming Birds (Replaces watchlistBirds/recommendedBirds)
    
    /// Get birds the user should see on the home screen
    /// Combines watchlist + hotspot data
    func getUpcomingBirds(
        userLocation: CLLocationCoordinate2D? = nil,
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) -> [UpcomingBirdResult] {
        
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        // Try user's current location first
        if let location = userLocation {
            return watchlistManager.getUpcomingBirds(
                userLocation: location,
                currentWeek: currentWeek,
                lookAheadWeeks: lookAheadWeeks,
                radiusInKm: radiusInKm
            )
        }
        
        // Fallback to home location
        if let homeLocation = LocationPreferences.shared.homeLocation {
            return watchlistManager.getUpcomingBirds(
                userLocation: homeLocation,
                currentWeek: currentWeek,
                lookAheadWeeks: lookAheadWeeks,
                radiusInKm: radiusInKm
            )
        }
        
        // No location available - return empty
        print("⚠️ [HomeManager] No location available for upcoming birds")
        return []
    }
    
    /// Get recommended birds based on location (not on watchlist)
    func getRecommendedBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int? = nil,
        radiusInKm: Double = 50.0,
        limit: Int = 10
    ) -> [Bird] {
        
        let week = currentWeek ?? Calendar.current.component(.weekOfYear, from: Date())
        
        // Get birds present at location
        let birdsAtLocation = hotspotManager.getBirdsPresent(
            at: userLocation,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        
        // Filter out birds already on watchlist
        let watchlistBirdIds = Set(
            watchlistManager.fetchEntries(watchlistID: WatchlistConstants.myWatchlistID)
                .compactMap { $0.bird?.id }
        )
        
        let recommended = birdsAtLocation.filter { !watchlistBirdIds.contains($0.id) }
        
        return Array(recommended.prefix(limit))
    }
    
    // MARK: - Popular Spots (Replaces watchlistSpots/recommendedSpots)
    
    /// Get spots the user is tracking via watchlist
    func getWatchlistSpots() -> [PopularSpotResult] {
        // Get all watchlists with location data
        let watchlists = watchlistManager.fetchWatchlists()
        
        return watchlists.compactMap { watchlist -> PopularSpotResult? in
            guard let location = watchlist.location,
                  let lat = parseLatitude(from: location),
                  let lon = parseLongitude(from: location) else {
                return nil
            }
            
            let birdCount = watchlist.entries?.count ?? 0
            let observedCount = watchlist.entries?.filter { $0.status == .observed }.count ?? 0
            
            return PopularSpotResult(
                id: watchlist.id,
                title: watchlist.title ?? "Unnamed Spot",
                location: watchlist.locationDisplayName ?? location,
                latitude: lat,
                longitude: lon,
                speciesCount: birdCount,
                observedCount: observedCount,
                radius: 5.0, // Default
                imageName: watchlist.images?.first?.imagePath
            )
        }
    }
    
    /// Get recommended spots near user (not on watchlist)
    func getRecommendedSpots(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 100.0,
        limit: Int = 10
    ) -> [PopularSpotResult] {
        
        // Get all hotspots near location
        let descriptor = FetchDescriptor<Hotspot>()
        guard let allHotspots = try? modelContext.fetch(descriptor) else { return [] }
        
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        // Get watchlist spot IDs to filter out
        let watchlistSpotNames = Set(
            watchlistManager.fetchWatchlists()
                .compactMap { $0.location }
        )
        
        let recommended = nearbyHotspots
            .filter { !watchlistSpotNames.contains($0.name) }
            .prefix(limit)
        
        return recommended.map { hotspot in
            let speciesCount = hotspot.speciesList?.count ?? 0
            let distance = queryLoc.distance(from: CLLocation(latitude: hotspot.lat, longitude: hotspot.lon))
            
            return PopularSpotResult(
                id: hotspot.id,
                title: hotspot.name,
                location: hotspot.locality ?? "Unknown",
                latitude: hotspot.lat,
                longitude: hotspot.lon,
                speciesCount: speciesCount,
                observedCount: 0,
                radius: 5.0,
                imageName: nil,
                distanceKm: distance / 1000.0
            )
        }
    }
    
    // MARK: - Migration Cards (Dynamic)
    
    /// Get active migration events for home screen
    func getActiveMigrations(limit: Int = 5) -> [MigrationCardResult] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        // Get active migration sessions
        let activeSessions = migrationManager.getActiveMigrations(forWeek: currentWeek)
        
        return activeSessions.prefix(limit).compactMap { session -> MigrationCardResult? in
            guard let bird = session.bird,
                  let trajectory = migrationManager.getTrajectory(for: bird, duringWeek: currentWeek) else {
                return nil
            }
            
            let progress = calculateProgress(
                currentWeek: currentWeek,
                startWeek: session.startWeek,
                endWeek: session.endWeek
            )
            
            return MigrationCardResult(
                bird: bird,
                session: session,
                currentPosition: trajectory.mostLikelyPosition,
                progress: progress,
                paths: trajectory.pathsAtWeek
            )
        }
    }
    
    private func calculateProgress(currentWeek: Int, startWeek: Int, endWeek: Int) -> Float {
        let totalWeeks = endWeek - startWeek
        guard totalWeeks > 0 else { return 0.5 }
        
        let elapsed = currentWeek - startWeek
        return Float(elapsed) / Float(totalWeeks)
    }
    
    // MARK: - Community Observations (Dynamic)
    
    /// Get recent community observations for home screen
    func getRecentObservations(
        near location: CLLocationCoordinate2D? = nil,
        radiusInKm: Double = 50.0,
        limit: Int = 10,
        maxAge: TimeInterval = 7 * 24 * 3600 // 7 days
    ) -> [CommunityObservation] {
        
        if let location = location {
            return observationManager.getObservations(
                near: location,
                radiusInKm: radiusInKm,
                maxAge: maxAge
            ).prefix(limit).map { $0 }
        }
        
        // Fallback: Get globally recent observations
        let descriptor = FetchDescriptor<CommunityObservation>(
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )
        
        let cutoff = Date().addingTimeInterval(-maxAge)
        let allRecent = (try? modelContext.fetch(descriptor)) ?? []
        
        return allRecent
            .filter { $0.observedAt >= cutoff }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Bird Categories (Static - Keep from JSON)
    
    func getBirdCategories() -> [BirdCategory] {
        // These can remain static or be generated from Bird.family
        return [
            BirdCategory(icon: "🦆", title: "Waterfowl"),
            BirdCategory(icon: "🦅", title: "Raptors"),
            BirdCategory(icon: "🐦", title: "Songbirds"),
            BirdCategory(icon: "🦉", title: "Owls"),
            BirdCategory(icon: "🦜", title: "Parrots"),
            BirdCategory(icon: "🕊️", title: "Doves")
        ]
    }
    
    // MARK: - Combined Home Data
    
    /// Get all data for home screen in one call
    func getHomeScreenData(
        userLocation: CLLocationCoordinate2D? = nil
    ) async -> HomeScreenData {
        
        let location = userLocation ?? LocationPreferences.shared.homeLocation
        
        return HomeScreenData(
            upcomingBirds: getUpcomingBirds(userLocation: location),
            recommendedBirds: location.map { getRecommendedBirds(userLocation: $0) } ?? [],
            watchlistSpots: getWatchlistSpots(),
            recommendedSpots: location.map { getRecommendedSpots(near: $0) } ?? [],
            activeMigrations: getActiveMigrations(),
            recentObservations: getRecentObservations(near: location),
            birdCategories: getBirdCategories()
        )
    }
    
    // MARK: - Legacy Prediction Support (For Backward Compatibility)
    
    /// Live predictions at a specific location (replaces getLivePredictions)
    func getLivePredictions(
        for lat: Double,
        lon: Double,
        radiusKm: Double
    ) -> [FinalPredictionResult] {
        
        let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        let birds = hotspotManager.getBirdsPresent(
            at: location,
            duringWeek: currentWeek,
            radiusInKm: radiusKm
        )
        
        return birds.map { bird in
            FinalPredictionResult(
                birdName: bird.commonName,
                imageName: bird.staticImageName,
                matchedInputIndex: 0,
                matchedLocation: (lat: lat, lon: lon),
                spottingProbability: 75 // Default probability
            )
        }
    }
    
    // MARK: - Helpers
    
    private func parseLatitude(from locationString: String) -> Double? {
        // Parse "lat,lon" format or use geocoding
        let components = locationString.components(separatedBy: ",")
        if components.count == 2,
           let lat = Double(components[0].trimmingCharacters(in: .whitespaces)) {
            return lat
        }
        return nil
    }
    
    private func parseLongitude(from locationString: String) -> Double? {
        let components = locationString.components(separatedBy: ",")
        if components.count == 2,
           let lon = Double(components[1].trimmingCharacters(in: .whitespaces)) {
            return lon
        }
        return nil
    }

    // MARK: - Legacy Compatibility (Bridging Types)

    func getDynamicMapCards() -> [DynamicMapCard] {
        let migrations = getActiveMigrations()

        return migrations.map { migration in
            let hotspot = HotspotPrediction(
                placeName: migration.currentPosition == nil ? "Unknown" : "Hotspot",
                speciesCount: 0,
                distanceString: "",
                dateRange: migration.dateRange,
                placeImageName: "default_spot",
                hotspots: []
            )

            let prediction = MigrationPrediction(
                birdName: migration.bird.commonName,
                birdImageName: migration.bird.staticImageName,
                startLocation: "",
                endLocation: "",
                currentProgress: migration.progress,
                dateRange: migration.dateRange,
                pathCoordinates: migration.paths.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                }
            )

            return .combined(migration: prediction, hotspot: hotspot)
        }
    }

    func parseDateRange(_ text: String) -> (Date?, Date?) {
        let parts = text.components(separatedBy: "-")
        guard parts.count >= 2 else { return (nil, nil) }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let start = formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces))
        let end = formatter.date(from: parts[1].trimmingCharacters(in: .whitespaces))
        return (start, end)
    }

    func predictBirds(for input: PredictionInputData, inputIndex: Int) -> [FinalPredictionResult] {
        guard let lat = input.latitude,
              let lon = input.longitude else {
            return []
        }

        return getLivePredictions(for: lat, lon: lon, radiusKm: Double(input.areaValue))
            .map { result in
                FinalPredictionResult(
                    birdName: result.birdName,
                    imageName: result.imageName,
                    matchedInputIndex: inputIndex,
                    matchedLocation: result.matchedLocation,
                    spottingProbability: result.spottingProbability
                )
            }
    }

    func getRelevantSightings(for input: BirdDateInput) -> [RelevantSighting] {
        return []
    }
}

struct DynamicMapCard {
    enum CardType {
        case combined(migration: MigrationPrediction, hotspot: HotspotPrediction)
    }

    let type: CardType

    static func combined(migration: MigrationPrediction, hotspot: HotspotPrediction) -> DynamicMapCard {
        DynamicMapCard(type: .combined(migration: migration, hotspot: hotspot))
    }
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
    let speciesCount: Int
    let distanceString: String
    let dateRange: String
    let placeImageName: String
    let hotspots: [HotspotBirdSpot]
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

// MARK: - Result Types

struct HomeScreenData {
    let upcomingBirds: [UpcomingBirdResult]
    let recommendedBirds: [Bird]
    let watchlistSpots: [PopularSpotResult]
    let recommendedSpots: [PopularSpotResult]
    let activeMigrations: [MigrationCardResult]
    let recentObservations: [CommunityObservation]
    let birdCategories: [BirdCategory]
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
    let progress: Float // 0.0 to 1.0
    let paths: [TrajectoryPath]
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        if let startDate = calendar.date(from: DateComponents(weekOfYear: session.startWeek)),
           let endDate = calendar.date(from: DateComponents(weekOfYear: session.endWeek)) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return "Week \(session.startWeek) - \(session.endWeek)"
    }
}
