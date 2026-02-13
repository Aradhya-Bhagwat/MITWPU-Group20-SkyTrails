//
//  HomeManager.swift
//  SkyTrails
//
//  Migrated to SwiftData Integration
//  Combined Manager for Home Module
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
            print("[upcomingbirdsdebug] HomeManager.getUpcomingBirds: Fetching for user location: \(location)")
            let results = watchlistManager.getUpcomingBirds(
                userLocation: location,
                currentWeek: currentWeek,
                lookAheadWeeks: lookAheadWeeks,
                radiusInKm: radiusInKm
            )
            print("[upcomingbirdsdebug] HomeManager.getUpcomingBirds: Found \(results.count) birds in watchlist")
            return results
        }
        
        // Fallback to home location
        if let homeLocation = LocationPreferences.shared.homeLocation {
            print("[upcomingbirdsdebug] HomeManager.getUpcomingBirds: Fetching for home location: \(homeLocation)")
            let results = watchlistManager.getUpcomingBirds(
                userLocation: homeLocation,
                currentWeek: currentWeek,
                lookAheadWeeks: lookAheadWeeks,
                radiusInKm: radiusInKm
            )
            print("[upcomingbirdsdebug] HomeManager.getUpcomingBirds: Found \(results.count) birds in watchlist (using home location)")
            return results
        }
        
        // No location available - return empty
        print("[upcomingbirdsdebug] ⚠️ HomeManager.getUpcomingBirds: No location available")
        return []
    }
    
    /// Get recommended birds based on location (not on watchlist)
    func getRecommendedBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int? = nil,
        radiusInKm: Double = 50.0,
        limit: Int = 10
    ) -> [RecommendedBirdResult] {
        
        let week = currentWeek ?? Calendar.current.component(.weekOfYear, from: Date())
        print("[upcomingbirdsdebug] HomeManager.getRecommendedBirds: Fetching for week \(week) at \(userLocation)")
        
        // Get birds present at location
        let birdsAtLocation = hotspotManager.getBirdsPresent(
            at: userLocation,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        
        // Find date range for each bird
        let results = birdsAtLocation.prefix(limit).map { bird in
            let dateRange = getMigrationDateRange(for: bird, userLocation: userLocation, radiusInKm: radiusInKm)
            return RecommendedBirdResult(bird: bird, dateRange: dateRange)
        }
        
        print("[upcomingbirdsdebug] HomeManager.getRecommendedBirds: Returning \(results.count) recommended birds (unfiltered)")
        
        return results
    }
    
    /// Get birds from user's watchlist that are currently present at their location
    func getMyWatchlistBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int? = nil,
        radiusInKm: Double = 50.0
    ) -> [UpcomingBirdResult] {
        
        let week = currentWeek ?? Calendar.current.component(.weekOfYear, from: Date())
        print("[upcomingbirdsdebug] HomeManager.getMyWatchlistBirds: Fetching for week \(week) at \(userLocation)")
        
        // Get birds present at location
        let birdsAtLocation = hotspotManager.getBirdsPresent(
            at: userLocation,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        print("[upcomingbirdsdebug] HomeManager.getMyWatchlistBirds: Found \(birdsAtLocation.count) birds at location")
        
        // Get watchlist entries (to_observe status only)
        let watchlistEntries = watchlistManager.fetchEntries(
            watchlistID: WatchlistConstants.myWatchlistID,
            status: .to_observe
        )
        print("[upcomingbirdsdebug] HomeManager.getMyWatchlistBirds: Found \(watchlistEntries.count) to_observe entries in watchlist")
        
        // Find intersection: birds in watchlist AND at location
        var results: [UpcomingBirdResult] = []
        for entry in watchlistEntries {
            guard let bird = entry.bird else { continue }
            
            if birdsAtLocation.contains(where: { $0.id == bird.id }) {
                let dateRange = getMigrationDateRange(for: bird, userLocation: userLocation, radiusInKm: radiusInKm)
                results.append(UpcomingBirdResult(
                    bird: bird,
                    entry: entry,
                    expectedWeek: week,
                    daysUntil: 0, // Present now
                    migrationDateRange: dateRange
                ))
            }
        }
        
        print("[upcomingbirdsdebug] HomeManager.getMyWatchlistBirds: Returning \(results.count) watchlist birds present at location")
        return results
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
                  let trajectory = migrationManager.getTrajectory(for: session, duringWeek: currentWeek) else {
                return nil
            }
            
            let progress = calculateProgress(
                currentWeek: currentWeek,
                startWeek: session.startWeek,
                endWeek: session.endWeek
            )
            
            // Return ALL paths for the trajectory so the map can draw the full path
            let allPaths = (session.trajectoryPaths ?? []).sorted(by: { $0.week < $1.week })
            
            return MigrationCardResult(
                bird: bird,
                session: session,
                currentPosition: trajectory.mostLikelyPosition,
                progress: progress,
                paths: allPaths
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
            myWatchlistBirds: location.map { getMyWatchlistBirds(userLocation: $0) } ?? [],
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
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        print("🔍 [HomeManager] getDynamicMapCards called - Current week: \(currentWeek)")
        
        let migrations = getActiveMigrations()
        print("🔍 [HomeManager] Found \(migrations.count) active migrations")
        
        if migrations.isEmpty {
            print("⚠️ [HomeManager] No active migrations found for current week \(currentWeek)")
            print("⚠️ [HomeManager] This will cause section 0 to be empty!")
        }

        let cards = migrations.map { migration in
            print("🔍 [HomeManager] Creating card for \(migration.bird.commonName)")
            print("   - Progress: \(migration.progress)")
            print("   - Date range: \(migration.dateRange)")
            print("   - Path points: \(migration.paths.count)")
            print("   - Current position: \(String(describing: migration.currentPosition))")
            
            // Get start and end locations from trajectory
            let startLocation: String
            let endLocation: String
            
            if let firstPath = migration.paths.first {
                startLocation = "(\(String(format: "%.2f", firstPath.lat)), \(String(format: "%.2f", firstPath.lon)))"
            } else {
                startLocation = "Unknown"
            }
            
            if let lastPath = migration.paths.last {
                endLocation = "(\(String(format: "%.2f", lastPath.lat)), \(String(format: "%.2f", lastPath.lon)))"
            } else {
                endLocation = "Unknown"
            }
            
            // Try to find nearby hotspot for this migration
            let nearbyHotspots = findNearbyHotspots(for: migration)
            let topHotspot = nearbyHotspots.first
            
            let hotspot = HotspotPrediction(
                placeName: topHotspot?.name ?? "Migration Zone",
                speciesCount: topHotspot?.speciesList?.count ?? 0,
                distanceString: topHotspot != nil ? "Nearby" : "N/A",
                dateRange: migration.dateRange,
                placeImageName: topHotspot?.imageName ?? "default_spot",
                hotspots: nearbyHotspots.prefix(3).map { hotspot in
                    HotspotBirdSpot(
                        coordinate: CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon),
                        birdImageName: migration.bird.staticImageName
                    )
                }
            )

            let prediction = MigrationPrediction(
                birdName: migration.bird.commonName,
                birdImageName: migration.bird.staticImageName,
                startLocation: startLocation,
                endLocation: endLocation,
                currentProgress: migration.progress,
                dateRange: migration.dateRange,
                pathCoordinates: migration.paths.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                }
            )

            return DynamicMapCard.combined(migration: prediction, hotspot: hotspot)
        }
        
        print("✅ [HomeManager] Created \(cards.count) dynamic map cards")
        return cards
    }
    
    private func findNearbyHotspots(for migration: MigrationCardResult) -> [Hotspot] {
        guard let currentPos = migration.currentPosition else { return [] }
        
        let descriptor = FetchDescriptor<Hotspot>()
        guard let allHotspots = try? modelContext.fetch(descriptor) else { return [] }
        
        let currentLoc = CLLocation(latitude: currentPos.latitude, longitude: currentPos.longitude)
        let nearby = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: currentLoc) <= 100_000 // 100km
        }
        
        return Array(nearby.prefix(3))
    }

    func parseDateRange(_ text: String) -> (Date?, Date?) {
        let parts = text.components(separatedBy: "-")
        guard parts.count >= 2 else { return (nil, nil) }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let currentYear = Calendar.current.component(.year, from: Date())

        var start = formatter.date(from: parts[0].trimmingCharacters(in: .whitespaces))
        var end = formatter.date(from: parts[1].trimmingCharacters(in: .whitespaces))

        let calendar = Calendar.current
        if let s = start {
            var comps = calendar.dateComponents([.month, .day], from: s)
            comps.year = currentYear
            start = calendar.date(from: comps)
        }
        if let e = end {
            var comps = calendar.dateComponents([.month, .day], from: e)
            comps.year = currentYear
            end = calendar.date(from: comps)
        }

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
        guard let birdId = UUID(uuidString: input.species.id) else { return [] }

        let birdDescriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { bird in
                bird.id == birdId
            }
        )

        guard let bird = try? modelContext.fetch(birdDescriptor).first else { return [] }

        let sessions = migrationManager.getSessions(for: bird)
        guard !sessions.isEmpty else { return [] }

        let calendar = Calendar.current
        let fallbackWeek = calendar.component(.weekOfYear, from: Date())
        let startWeek = input.startDate?.weekOfYear ?? fallbackWeek
        let endWeek = input.endDate?.weekOfYear ?? ((startWeek + 4 - 1) % 52 + 1)

        let isWrapping = endWeek < startWeek

        var sightings: [RelevantSighting] = []
        for session in sessions {
            guard let paths = session.trajectoryPaths else { continue }

            let relevantPaths = paths.filter { path in
                if isWrapping {
                    return path.week >= startWeek || path.week <= endWeek
                }
                return path.week >= startWeek && path.week <= endWeek
            }

            for path in relevantPaths {
                sightings.append(
                    RelevantSighting(lat: path.lat, lon: path.lon, week: path.week)
                )
            }
        }

        return sightings.sorted { $0.week < $1.week }
    }

    // MARK: - Migration Helpers

    /// Gets migration date range for a bird at a specific location
    func getMigrationDateRange(for bird: Bird, userLocation: CLLocationCoordinate2D, radiusInKm: Double) -> String {
        // 1. Try to find an active migration session for this bird
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let sessions = migrationManager.getSessions(for: bird)
        
        // Find session that passes through user location
        for session in sessions {
            let paths = session.trajectoryPaths ?? []
            let passesThrough = paths.contains { path in
                let pathLoc = CLLocation(latitude: path.lat, longitude: path.lon)
                let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                return pathLoc.distance(from: userLoc) <= (radiusInKm * 1000)
            }
            
            if passesThrough {
                return formatWeekRange(startWeek: session.startWeek, endWeek: session.endWeek)
            }
        }
        
        // 2. Fallback: Try to get from hotspot validWeeks
        let descriptor = FetchDescriptor<Hotspot>()
        if let hotspots = try? modelContext.fetch(descriptor) {
            let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let nearbyHotspots = hotspots.filter { hotspot in
                let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
                return hotspotLoc.distance(from: userLoc) <= (radiusInKm * 1000)
            }
            
            for hotspot in nearbyHotspots {
                if let speciesList = hotspot.speciesList {
                    if let presence = speciesList.first(where: { $0.bird?.id == bird.id }) {
                        if let weeks = presence.validWeeks {
                            let sortedWeeks = weeks.sorted()
                            if let first = sortedWeeks.first, let last = sortedWeeks.last {
                                return formatWeekRange(startWeek: first, endWeek: last)
                            }
                        }
                    }
                }
            }
        }
        
        return "Season pending"
    }

    /// Formats a week range into "MMM d - MMM d" string
    func formatWeekRange(startWeek: Int, endWeek: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var startComponents = DateComponents()
        startComponents.weekOfYear = startWeek
        startComponents.yearForWeekOfYear = currentYear
        startComponents.weekday = 2 // Monday
        
        var endComponents = DateComponents()
        endComponents.weekOfYear = endWeek
        endComponents.yearForWeekOfYear = currentYear
        endComponents.weekday = 2 // Monday
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        
        return "Week \(startWeek) - \(endWeek)"
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
    let myWatchlistBirds: [UpcomingBirdResult]
    let recommendedBirds: [RecommendedBirdResult]
    let watchlistSpots: [PopularSpotResult]
    let recommendedSpots: [PopularSpotResult]
    let activeMigrations: [MigrationCardResult]
    let recentObservations: [CommunityObservation]
    let birdCategories: [BirdCategory]
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
        let currentYear = calendar.component(.year, from: Date())
        
        var startComponents = DateComponents()
        startComponents.weekOfYear = session.startWeek
        startComponents.yearForWeekOfYear = currentYear
        startComponents.weekday = 2 // Monday
        
        var endComponents = DateComponents()
        endComponents.weekOfYear = session.endWeek
        endComponents.yearForWeekOfYear = currentYear
        endComponents.weekday = 2 // Monday
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return "Week \(session.startWeek) - \(session.endWeek)"
    }
}

// MARK: - Sub-Managers

@MainActor
final class HotspotManager {
    private let modelContext: ModelContext
    
    // Cache: key = "lat_lon_week_radius", value = [Bird]
    private var birdsCache: [String: [Bird]] = [:]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get birds present at a location during a specific week
    func getBirdsPresent(
        at location: CLLocationCoordinate2D,
        duringWeek week: Int,
        radiusInKm: Double = 50.0
    ) -> [Bird] {
        // 0. Check Cache
        let cacheKey = "\(location.latitude)_\(location.longitude)_\(week)_\(radiusInKm)"
        if let cached = birdsCache[cacheKey] {
            return cached
        }
        
        print("[homeseeder] 🔍 [HotspotManager] Finding birds at \(location.latitude), \(location.longitude) for week \(week)")
        
        // 1. Fetch all hotspots (spatial query optimization would happen here in production)
        let descriptor = FetchDescriptor<Hotspot>()
        guard let allHotspots = try? modelContext.fetch(descriptor) else {
            print("[homeseeder] ❌ [HotspotManager] Failed to fetch hotspots")
            return []
        }
        
        // 2. Filter hotspots by radius
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        print("[homeseeder] 📍 [HotspotManager] Found \(nearbyHotspots.count) hotspots within \(radiusInKm)km")
        
        // 3. Aggregate birds present this week
        var uniqueBirds: Set<Bird> = []
        
        for hotspot in nearbyHotspots {
            guard let speciesList = hotspot.speciesList else { continue }
            
            for presence in speciesList {
                // Check if bird is present this week
                if let weeks = presence.validWeeks, weeks.contains(week), let bird = presence.bird {
                    uniqueBirds.insert(bird)
                }
            }
        }
        
        print("[homeseeder] 🦜 [HotspotManager] Found \(uniqueBirds.count) unique bird species present")
        
        let result = Array(uniqueBirds)
        birdsCache[cacheKey] = result
        return result
    }
}

@MainActor
final class MigrationManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get active migrations for a specific week
    func getActiveMigrations(forWeek week: Int) -> [MigrationSession] {
        print("\n🔍 [MigrationManager] getActiveMigrations called")
        print("   📅 Searching for week: \(week)")
        print("   🔎 Predicate: startWeek <= \(week) AND endWeek >= \(week)")
        
        // First, get ALL sessions to debug
        let allDescriptor = FetchDescriptor<MigrationSession>()
        if let allSessions = try? modelContext.fetch(allDescriptor) {
            print("   📊 Total migration sessions in database: \(allSessions.count)")
            for (index, session) in allSessions.enumerated() {
                let birdName = session.bird?.commonName ?? "Unknown Bird"
                let isActive = session.startWeek <= week && session.endWeek >= week
                let status = isActive ? "✅ ACTIVE" : "❌ INACTIVE"
                print("      [\(index)] \(birdName): weeks \(session.startWeek)-\(session.endWeek) \(status)")
            }
        }
        
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.startWeek <= week && session.endWeek >= week
            }
        )
        
        guard let activeSessions = try? modelContext.fetch(descriptor) else {
            print("   ❌ [MigrationManager] Fetch active migrations FAILED")
            return []
        }
        
        if activeSessions.isEmpty {
            print("   ⚠️  [MigrationManager] No active sessions found for week \(week)")
            print("   💡 Tip: Check if migration data was seeded correctly")
        } else {
            print("   ✅ [MigrationManager] Found \(activeSessions.count) active session(s)")
            for session in activeSessions {
                print("      - \(session.bird?.commonName ?? "Unknown")")
            }
        }
        
        return activeSessions
    }
    
    /// Get trajectory data for a session during a specific week
    func getTrajectory(for session: MigrationSession, duringWeek week: Int) -> MigrationTrajectoryResult? {
        // 1. Get paths for this week
        guard let allPaths = session.trajectoryPaths else {
            print("[homeseeder] ❌ [MigrationManager] Session found but trajectoryPaths is nil")
            return nil
        }
        
        let currentPaths = allPaths.filter { $0.week == week }
        
        // 2. Determine most likely position (highest probability)
        let bestPath = currentPaths.max(by: { ($0.probability ?? 0) < ($1.probability ?? 0) })
        let position: CLLocationCoordinate2D?
        if let lat = bestPath?.lat, let lon = bestPath?.lon {
            position = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            position = nil
        }
        
        return MigrationTrajectoryResult(
            session: session,
            pathsAtWeek: currentPaths,
            requestedWeek: week,
            mostLikelyPosition: position
        )
    }

    /// Get trajectory data for a bird during a specific week
    func getTrajectory(for bird: Bird, duringWeek week: Int) -> MigrationTrajectoryResult? {
        // 1. Find session for this bird
        let birdId = bird.id
        print("[homeseeder] 🦅 [MigrationManager] getTrajectory for bird: \(bird.commonName) (Week \(week))")
        
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.id == birdId &&
                session.startWeek <= week &&
                session.endWeek >= week
            }
        )
        
        guard let session = try? modelContext.fetch(descriptor).first else {
            print("[homeseeder] ❌ [MigrationManager] No session found for bird \(bird.commonName)")
            return nil
        }
        
        return getTrajectory(for: session, duringWeek: week)
    }

    /// Get all migration sessions for a specific bird
    func getSessions(for bird: Bird) -> [MigrationSession] {
        let birdId = bird.id
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.id == birdId
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

@MainActor
final class CommunityObservationManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get community observations near a location
    func getObservations(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 50.0,
        maxAge: TimeInterval? = nil
    ) -> [CommunityObservation] {
        print("[homeseeder] 🔍 [CommunityObservationManager] Fetching observations...")
        
        // 1. Base Descriptor
        var descriptor = FetchDescriptor<CommunityObservation>(
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )
        
        // 2. Filter by date if needed (Predicate)
        if let maxAge = maxAge {
            let cutoffDate = Date().addingTimeInterval(-maxAge)
            descriptor.predicate = #Predicate { obs in
                obs.observedAt >= cutoffDate
            }
        }
        
        // 3. Fetch
        guard let allObservations = try? modelContext.fetch(descriptor) else {
            print("[homeseeder] ❌ [CommunityObservationManager] Fetch failed")
            return []
        }
        
        print("[homeseeder] 📊 [CommunityObservationManager] Fetched \(allObservations.count) potential observations")
        
        // 4. Filter by location (In-memory)
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        let filtered = allObservations.filter { obs in
            guard let lat = obs.lat, let lon = obs.lon else { return false }
            let obsLoc = CLLocation(latitude: lat, longitude: lon)
            return obsLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        print("[homeseeder] 📍 [CommunityObservationManager] \(filtered.count) observations within \(radiusInKm)km of \(location)")
        
        return filtered
    }
}
