//
//  HomeManager.swift
//  SkyTrails
//
//  Refactored to Strict MVC, Dependency Injection & Robust Error Handling
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
class HomeManager {
    
    static let shared = HomeManager()
    
    private let watchlistManager: WatchlistManager
    private let hotspotManager: HotspotManager
    private let migrationManager: MigrationManager
    private let observationManager: CommunityObservationManager
    private let newsService: NewsServiceProtocol
    private let locationService: LocationServiceProtocol
    private let logger: LoggingServiceProtocol
    
    // Cache for performance (NSCache for memory safety)
    let spotSpeciesCountCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 100
        cache.totalCostLimit = 50_000_000 // 50MB
        return cache
    }()
    
    // Internal init for testing
    init(
        watchlistManager: WatchlistManager? = nil,
        hotspotManager: HotspotManager? = nil,
        migrationManager: MigrationManager? = nil,
        observationManager: CommunityObservationManager? = nil,
        newsService: NewsServiceProtocol? = nil,
        locationService: LocationServiceProtocol? = nil,
        logger: LoggingServiceProtocol? = nil
    ) {
        let actualLogger = logger ?? LoggingService.shared
        let actualWatchlistManager = watchlistManager ?? WatchlistManager.shared
        
        self.watchlistManager = actualWatchlistManager
        self.logger = actualLogger
        
        let context = actualWatchlistManager.context
        self.hotspotManager = hotspotManager ?? HotspotManager(modelContext: context, logger: actualLogger)
        self.migrationManager = migrationManager ?? MigrationManager(modelContext: context, logger: actualLogger)
        self.observationManager = observationManager ?? CommunityObservationManager(modelContext: context, logger: actualLogger)
        
        self.newsService = newsService ?? NewsService()
        self.locationService = locationService ?? LocationService.shared
    }
    
    // MARK: - Core Data Fetching

    /// Get all data for home screen in one call, ready for UI display
    func getHomeScreenData(
        userLocation: CLLocationCoordinate2D? = nil
    ) async -> HomeScreenData {
        
        let location = userLocation ?? LocationPreferences.shared.homeLocation
        var errorOccurred: String? = nil
        
        // Parallel fetching
        async let upcoming = getUpcomingBirds(userLocation: location)
        async let myWatchlist: [UpcomingBirdResult] = {
            if let loc = location { return await getMyWatchlistBirds(userLocation: loc) }
            return []
        }()
        async let recommended: [RecommendedBirdResult] = {
            if let loc = location { return await getRecommendedBirds(userLocation: loc) }
            return []
        }()
        async let watchlistSpots = getWatchlistSpots()
        async let recommendedSpots: [PopularSpotResult] = {
            if let loc = location { return await getRecommendedSpots(near: loc) }
            return []
        }()
        async let mapCards = getDynamicMapCards()
        async let observations = getRecentObservations(near: location)
        async let news = newsService.fetchNews()
        
        do {
            let (
                upcomingResult,
                myWatchlistResult,
                recommendedResult,
                watchlistSpotsResult,
                recommendedSpotsResult,
                mapCardsResult,
                observationsResult,
                newsResult
            ) = await (
                upcoming,
                myWatchlist,
                recommended,
                watchlistSpots,
                recommendedSpots,
                mapCards,
                try observations,
                news
            )

            return HomeScreenData(
                upcomingBirds: upcomingResult,
                myWatchlistBirds: myWatchlistResult,
                recommendedBirds: recommendedResult,
                watchlistSpots: watchlistSpotsResult,
                recommendedSpots: recommendedSpotsResult,
                migrationCards: mapCardsResult,
                recentObservations: observationsResult,
                birdCategories: getBirdCategories(),
                news: newsResult,
                errorMessage: nil
            )
        } catch {
            logger.log(error: error, context: "HomeManager.getHomeScreenData")
            errorOccurred = "Failed to load some dashboard items. Please check your connection."
            
            // Return empty data with error message
            return HomeScreenData(
                upcomingBirds: [],
                myWatchlistBirds: [],
                recommendedBirds: [],
                watchlistSpots: [],
                recommendedSpots: [],
                migrationCards: [],
                recentObservations: [],
                birdCategories: getBirdCategories(),
                news: [],
                errorMessage: errorOccurred
            )
        }
    }
    
    // MARK: - Upcoming Birds
    
    func getUpcomingBirds(
        userLocation: CLLocationCoordinate2D? = nil,
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) async -> [UpcomingBirdResult] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        if let location = userLocation ?? LocationPreferences.shared.homeLocation {
             return (try? await watchlistManager.getUpcomingBirds(
                userLocation: location,
                currentWeek: currentWeek,
                lookAheadWeeks: lookAheadWeeks,
                radiusInKm: radiusInKm
            )) ?? []
        }
        return []
    }
    
    func getRecommendedBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int? = nil,
        radiusInKm: Double = 50.0,
        limit: Int = 10
    ) async -> [RecommendedBirdResult] {
        let week = currentWeek ?? Calendar.current.component(.weekOfYear, from: Date())
        
        let birdsAtLocation = await hotspotManager.getBirdsPresent(
            at: userLocation,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        
        return birdsAtLocation.prefix(limit).map { bird in
            let dateRange = getMigrationDateRange(for: bird, userLocation: userLocation, radiusInKm: radiusInKm)
            return RecommendedBirdResult(bird: bird, dateRange: dateRange)
        }
    }
    
    func getMyWatchlistBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int? = nil,
        radiusInKm: Double = 50.0
    ) async -> [UpcomingBirdResult] {
        let week = currentWeek ?? Calendar.current.component(.weekOfYear, from: Date())
        
        let birdsAtLocation = await hotspotManager.getBirdsPresent(
            at: userLocation,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        
        let watchlistEntries = (try? watchlistManager.fetchEntries(
            watchlistID: WatchlistConstants.myWatchlistID,
            status: .to_observe
        )) ?? []
        
        var results: [UpcomingBirdResult] = []
        let locationBirdIds = Set(birdsAtLocation.map { $0.id })
        
        for entry in watchlistEntries {
            guard let bird = entry.bird else { continue }
            
            if locationBirdIds.contains(bird.id) {
                let dateRange = getMigrationDateRange(for: bird, userLocation: userLocation, radiusInKm: radiusInKm)
                results.append(UpcomingBirdResult(
                    bird: bird,
                    entry: entry,
                    expectedWeek: week,
                    daysUntil: 0,
                    migrationDateRange: dateRange
                ))
            }
        }
        return results
    }
    
    // MARK: - Spots
    
    func getWatchlistSpots() async -> [PopularSpotResult] {
        let watchlists = (try? watchlistManager.fetchWatchlists()) ?? []
        
        return watchlists.compactMap { watchlist -> PopularSpotResult? in
            guard let location = watchlist.location,
                  let coordinate = locationService.parseCoordinate(from: location) else {
                return nil
            }
            
            let birdCount = watchlist.entries?.count ?? 0
            let observedCount = watchlist.entries?.filter { $0.status == .observed }.count ?? 0
            
            // Cache species count for grid view
            spotSpeciesCountCache.setObject(NSNumber(value: birdCount), forKey: (watchlist.title ?? "Unknown") as NSString)

            return PopularSpotResult(
                id: watchlist.id,
                title: watchlist.title ?? "Unnamed Spot",
                location: watchlist.locationDisplayName ?? location,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                speciesCount: birdCount,
                observedCount: observedCount,
                radius: 5.0,
                imageName: watchlist.coverImagePath
            )
        }
    }
    
    func getRecommendedSpots(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 100.0,
        limit: Int = 10
    ) async -> [PopularSpotResult] {
        
        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedSpots")
            allHotspots = []
        }
        
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            return locationService.distance(from: location, to: hotspotLoc) <= (radiusInKm * 1000)
        }
        
        let watchlistSpotNames = Set((try? watchlistManager.fetchWatchlists())?.compactMap { $0.location } ?? [])
        
        let recommended = nearbyHotspots
            .filter { !watchlistSpotNames.contains($0.name) }
            .prefix(limit)
        
        return recommended.map { hotspot in
            let speciesCount = hotspot.speciesList?.count ?? 0
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            let distance = locationService.distance(from: location, to: hotspotLoc)
            
            // Cache species count
            spotSpeciesCountCache.setObject(NSNumber(value: speciesCount), forKey: hotspot.name as NSString)

            return PopularSpotResult(
                id: hotspot.id,
                title: hotspot.name,
                location: hotspot.locality ?? "Unknown",
                latitude: hotspot.lat,
                longitude: hotspot.lon,
                speciesCount: speciesCount,
                observedCount: 0,
                radius: 5.0,
                imageName: hotspot.imageName,
                distanceKm: distance / 1000.0
            )
        }
    }
    
    // MARK: - Migration & Community
    
    func getActiveMigrations(limit: Int = 5) async -> [MigrationCardResult] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let activeSessions = await migrationManager.getActiveMigrations(forWeek: currentWeek)
        
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
    
    func getDynamicMapCards() async -> [DynamicMapCard] {
        print("🃏 [PredictionDebug] getDynamicMapCards: Starting card assembly")
        let migrations = await getActiveMigrations()
        print("🃏 [PredictionDebug]   Active migrations received: \(migrations.count)")
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        print("🃏 [PredictionDebug]   Current week for hotspot lookup: \(currentWeek)")
        
        var cards: [DynamicMapCard] = []
        
        for (index, migration) in migrations.enumerated() {
            print("🃏 [PredictionDebug] Processing migration #\(index + 1): \(migration.bird.commonName)")
            let startLocation = migration.paths.first.map { "(\(String(format: "%.2f", $0.lat)), \(String(format: "%.2f", $0.lon)))" } ?? "Unknown"
            let endLocation = migration.paths.last.map { "(\(String(format: "%.2f", $0.lat)), \(String(format: "%.2f", $0.lon)))" } ?? "Unknown"
            
            let nearbyHotspots = findNearbyHotspots(for: migration)
            print("🃏 [PredictionDebug]   Nearby hotspots found: \(nearbyHotspots.count)")
            let topHotspot = nearbyHotspots.first
            if let top = topHotspot {
                print("🃏 [PredictionDebug]   Top hotspot: \(top.name) at (\(top.lat), \(top.lon))")
            } else {
                print("⚠️ [PredictionDebug]   NO TOP HOTSPOT found within 100km of current position")
            }
            
            var displayBirds: [BirdSpeciesDisplay] = []
            
            if let top = topHotspot {
                let location = CLLocationCoordinate2D(latitude: top.lat, longitude: top.lon)
                let birds = await hotspotManager.getBirdsPresent(at: location, duringWeek: currentWeek, radiusInKm: 50.0)
                print("🃏 [PredictionDebug]   Birds present at hotspot: \(birds.count)")
                
                displayBirds = birds.prefix(5).map { bird in
                    // Find presence for this specific hotspot if possible to get probability
                    let presence = top.speciesList?.first(where: { $0.bird?.id == bird.id })
                    let prob = presence?.probability ?? Int.random(in: 60...90)
                    print("🃏 [PredictionDebug]     → \(bird.commonName) (\(prob)%)")
                    
                    return BirdSpeciesDisplay(
                        birdName: bird.commonName,
                        birdImageName: bird.staticImageName,
                        statusBadge: BirdSpeciesDisplay.StatusBadge(
                            title: "Local Species",
                            subtitle: "Year-round",
                            iconName: "mappin.and.ellipse",
                            backgroundColorName: "BadgePink"
                        ),
                        sightabilityPercent: prob
                    )
                }
            }
            
            print("🃏 [PredictionDebug]   Final displayBirds array count: \(displayBirds.count)")
            
            let hotspot = HotspotPrediction(
                placeName: topHotspot?.name ?? "Migration Zone",
                speciesCount: topHotspot?.speciesList?.count ?? 0,
                distanceString: topHotspot != nil ? "Nearby" : "N/A",
                dateRange: migration.dateRange,
                placeImageName: topHotspot?.imageName ?? "placeholder_image",
                hotspots: nearbyHotspots.prefix(3).map { hotspot in
                    HotspotBirdSpot(
                        coordinate: CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon),
                        birdImageName: migration.bird.staticImageName
                    )
                },
                birdSpecies: displayBirds
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

            print("🃏 [PredictionDebug]   Created combined card for: \(prediction.birdName)")
            cards.append(DynamicMapCard.combined(migration: prediction, hotspot: hotspot))
        }
        
        print("🃏 [PredictionDebug] Total DynamicMapCards created: \(cards.count)")
        return cards
    }
    
    func getRecentObservations(
        near location: CLLocationCoordinate2D? = nil,
        radiusInKm: Double = 50.0,
        limit: Int = 10,
        maxAge: TimeInterval = 7 * 24 * 3600
    ) async throws -> [CommunityObservation] {
        if let location = location {
            return try observationManager.getObservations(near: location, radiusInKm: radiusInKm, maxAge: maxAge)
                .prefix(limit).map { $0 }
        }
        
        let descriptor = FetchDescriptor<CommunityObservation>(
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )
        let cutoff = Date().addingTimeInterval(-maxAge)
        let allRecent: [CommunityObservation]
        do {
            allRecent = try watchlistManager.fetchAll(CommunityObservation.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.getRecentObservations")
            throw error
        }
        
        return allRecent
            .filter { $0.observedAt >= cutoff }
            .prefix(limit)
            .map { $0 }
    }
    
    func getBirdCategories() -> [BirdCategory] {
        return [
            BirdCategory(icon: "🦆", title: "Waterfowl"),
            BirdCategory(icon: "🦅", title: "Raptors"),
            BirdCategory(icon: "🐦", title: "Songbirds"),
            BirdCategory(icon: "🦉", title: "Owls"),
            BirdCategory(icon: "🦜", title: "Parrots"),
            BirdCategory(icon: "🕊️", title: "Doves")
        ]
    }
    
    // MARK: - Helpers
    
    private func calculateProgress(currentWeek: Int, startWeek: Int, endWeek: Int) -> Float {
        let totalWeeks = endWeek - startWeek
        guard totalWeeks > 0 else { return 0.5 }
        let elapsed = currentWeek - startWeek
        return Float(elapsed) / Float(totalWeeks)
    }
    
    func getMigrationDateRange(for bird: Bird, userLocation: CLLocationCoordinate2D, radiusInKm: Double) -> String {
        let sessions = migrationManager.getSessions(for: bird)
        
        for session in sessions {
            let paths = session.trajectoryPaths ?? []
            let passesThrough = paths.contains { path in
                let pathLoc = CLLocationCoordinate2D(latitude: path.lat, longitude: path.lon)
                return locationService.distance(from: pathLoc, to: userLocation) <= (radiusInKm * 1000)
            }
            
            if passesThrough {
                return formatWeekRange(startWeek: session.startWeek, endWeek: session.endWeek)
            }
        }
        
        let descriptor = FetchDescriptor<Hotspot>()
        let hotspots: [Hotspot]
        do {
            hotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.getMigrationDateRange")
            hotspots = []
        }
        
        let nearbyHotspots = hotspots.filter { hotspot in
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            return locationService.distance(from: hotspotLoc, to: userLocation) <= (radiusInKm * 1000)
        }
        
        for hotspot in nearbyHotspots {
            if let speciesList = hotspot.speciesList,
               let presence = speciesList.first(where: { $0.bird?.id == bird.id }),
               let weeks = presence.validWeeks {
                let sortedWeeks = weeks.sorted()
                if let first = sortedWeeks.first, let last = sortedWeeks.last {
                    return formatWeekRange(startWeek: first, endWeek: last)
                }
            }
        }
        
        return "Season pending"
    }

    func formatWeekRange(startWeek: Int, endWeek: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var startComponents = DateComponents()
        startComponents.weekOfYear = startWeek
        startComponents.yearForWeekOfYear = currentYear
        startComponents.weekday = 2
        
        var endComponents = DateComponents()
        endComponents.weekOfYear = endWeek
        endComponents.yearForWeekOfYear = currentYear
        endComponents.weekday = 2
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        
        return "Week \(startWeek) - \(endWeek)"
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
    
    private func findNearbyHotspots(for migration: MigrationCardResult) -> [Hotspot] {
        guard let currentPos = migration.currentPosition else { return [] }
        
        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.findNearbyHotspots")
            allHotspots = []
        }
        
        let currentLoc = CLLocationCoordinate2D(latitude: currentPos.latitude, longitude: currentPos.longitude)
        
        let nearby = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            return locationService.distance(from: currentLoc, to: hotspotLoc) <= 100_000
        }
        
        return Array(nearby.prefix(3))
    }
    
    // MARK: - Legacy Compatibility

    func getLivePredictions(for lat: Double, lon: Double, radiusKm: Double) async -> [FinalPredictionResult] {
        let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        let birds = await hotspotManager.getBirdsPresent(
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
                spottingProbability: 75
            )
        }
    }
    
    func predictBirds(for input: PredictionInputData, inputIndex: Int) async -> [FinalPredictionResult] {
        guard let lat = input.latitude,
              let lon = input.longitude else {
            return []
        }

        return await getLivePredictions(for: lat, lon: lon, radiusKm: Double(input.areaValue))
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

        let bird: Bird?
        do {
            bird = try watchlistManager.fetchOne(Bird.self, descriptor: birdDescriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.getRelevantSightings")
            bird = nil
        }
        
        guard let b = bird else { return [] }

        let sessions = migrationManager.getSessions(for: b)
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
}

// MARK: - Sub-Managers

@MainActor
final class HotspotManager {
    private let modelContext: ModelContext
    private let logger: LoggingServiceProtocol
    
    // Cache: key = "lat_lon_week_radius", value = [Bird]
    private let birdsCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 100
        cache.totalCostLimit = 50_000_000 // 50MB
        return cache
    }()
    
    init(modelContext: ModelContext, logger: LoggingServiceProtocol? = nil) {
        self.modelContext = modelContext
        self.logger = logger ?? LoggingService.shared
    }
    
    func getBirdsPresent(
        at location: CLLocationCoordinate2D,
        duringWeek week: Int,
        radiusInKm: Double = 50.0
    ) async -> [Bird] {
        let cacheKey = "\(location.latitude)_\(location.longitude)_\(week)_\(radiusInKm)" as NSString
        if let cached = birdsCache.object(forKey: cacheKey) as? [Bird] {
            return cached
        }
        
        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try modelContext.fetch(descriptor)
        } catch {
            logger.log(error: error, context: "HotspotManager.getBirdsPresent")
            allHotspots = []
        }
        
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        var uniqueBirds: Set<Bird> = []
        for hotspot in nearbyHotspots {
            guard let speciesList = hotspot.speciesList else { continue }
            for presence in speciesList {
                if let weeks = presence.validWeeks, weeks.contains(week), let bird = presence.bird {
                    uniqueBirds.insert(bird)
                }
            }
        }
        
        let result = Array(uniqueBirds)
        birdsCache.setObject(result as NSArray, forKey: cacheKey)
        return result
    }
}

@MainActor
final class MigrationManager {
    private let modelContext: ModelContext
    private let logger: LoggingServiceProtocol
    
    init(modelContext: ModelContext, logger: LoggingServiceProtocol? = nil) {
        self.modelContext = modelContext
        self.logger = logger ?? LoggingService.shared
    }
    
    func getActiveMigrations(forWeek week: Int) async -> [MigrationSession] {
        print("🔍 [PredictionDebug] MigrationManager: Querying active migrations for week \(week)")
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.startWeek <= week && session.endWeek >= week
            }
        )
        do {
            let sessions = try modelContext.fetch(descriptor)
            print("🔍 [PredictionDebug]   Found \(sessions.count) active migration(s)")
            for session in sessions {
                print("🔍 [PredictionDebug]   Migration: \(session.bird?.commonName ?? "NO BIRD") (weeks \(session.startWeek)-\(session.endWeek))")
            }
            return sessions
        } catch {
            logger.log(error: error, context: "MigrationManager.getActiveMigrations")
            print("❌ [PredictionDebug] ERROR fetching migrations: \(error)")
            return []
        }
    }
    
    func getTrajectory(for session: MigrationSession, duringWeek week: Int) -> MigrationTrajectoryResult? {
        print("🗺️ [PredictionDebug] getTrajectory for: \(session.bird?.commonName ?? "Unknown") at week \(week)")
        guard let allPaths = session.trajectoryPaths else {
            print("❌ [PredictionDebug]   NO TRAJECTORY PATHS for session!")
            return nil
        }
        
        let currentPaths = allPaths.filter { $0.week == week }
        print("🗺️ [PredictionDebug]   Paths for week \(week): \(currentPaths.count)")
        let bestPath = currentPaths.max(by: { ($0.probability ?? 0) < ($1.probability ?? 0) })
        
        if let best = bestPath {
            print("🗺️ [PredictionDebug]   Best position: (\(best.lat), \(best.lon)) @ \(best.probability ?? 0)% probability")
        } else {
            print("⚠️ [PredictionDebug]   NO BEST PATH found for week \(week)")
        }
        
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

    func getSessions(for bird: Bird) -> [MigrationSession] {
        let birdId = bird.id
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.id == birdId
            }
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.log(error: error, context: "MigrationManager.getSessions")
            return []
        }
    }
}

@MainActor
final class CommunityObservationManager {
    private let modelContext: ModelContext
    private let logger: LoggingServiceProtocol
    
    init(modelContext: ModelContext, logger: LoggingServiceProtocol? = nil) {
        self.modelContext = modelContext
        self.logger = logger ?? LoggingService.shared
    }
    
    func getObservations(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 50.0,
        maxAge: TimeInterval? = nil
    ) throws -> [CommunityObservation] {
        
        let deltaLat = radiusInKm / 111.0
        let deltaLon = radiusInKm / (111.0 * cos(location.latitude * .pi / 180.0))
        
        let minLat = location.latitude - deltaLat
        let maxLat = location.latitude + deltaLat
        let minLon = location.longitude - deltaLon
        let maxLon = location.longitude + deltaLon
        
        let cutoffDate = maxAge.map { Date().addingTimeInterval(-$0) }
        let past = cutoffDate ?? Date.distantPast
        
        // SwiftData Predicate for spatial and temporal filtering
        let descriptor = FetchDescriptor<CommunityObservation>(
            predicate: #Predicate<CommunityObservation> { obs in
                if let lat = obs.lat, let lon = obs.lon {
                    return lat >= minLat && lat <= maxLat &&
                           lon >= minLon && lon <= maxLon &&
                           (cutoffDate == nil || obs.observedAt >= past)
                } else {
                    return false
                }
            },
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.log(error: error, context: "CommunityObservationManager.getObservations")
            throw error
        }
    }
}
