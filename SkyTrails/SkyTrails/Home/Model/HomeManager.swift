//
//  HomeManager.swift
//  SkyTrails
//
//  Refactored to Strict MVC, Dependency Injection & Robust Error Handling
//

import Foundation
import CoreLocation
import SwiftData
import MapKit

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
        async let mapCards = getDynamicMapCards(userLocation: location)
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
    
    func getDynamicMapCards(userLocation: CLLocationCoordinate2D? = nil) async -> [DynamicMapCard] {
        print("🃏 [PredictionDebug] getDynamicMapCards: Starting card assembly")

        // 1. Require user location — prefer passed-in value, fall back to live service
        guard let userLocation = userLocation ?? locationService.currentLocation else {
            print("⚠️ [PredictionDebug] getDynamicMapCards: No user location available")
            return []
        }
        print("🃏 [PredictionDebug]   User location: \(userLocation.latitude), \(userLocation.longitude)")

        // 2. Find all hotspots within 100 km of user, sorted closest-first
        let nearbyHotspots = findNearbyHotspots(near: userLocation, radiusKm: 100.0)
        print("🃏 [PredictionDebug]   Hotspots within 100km: \(nearbyHotspots.count)")
        guard !nearbyHotspots.isEmpty else {
            print("⚠️ [PredictionDebug]   No hotspots found near user — returning empty")
            return []
        }

        // 3. Build week range: current week + next 4 (wrap at 52)
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let weekRange = (currentWeek...(currentWeek + 4)).map { ($0 - 1) % 52 + 1 }
        print("🃏 [PredictionDebug]   Week range: \(weekRange)")

        // 4. Gather active migrations for context (bird IDs + path data)
        let migrations = await getActiveMigrations()
        let migratingBirdIds = Set(migrations.compactMap { $0.bird.id })
        let migrationsByBirdId: [UUID: MigrationCardResult] = Dictionary(
            migrations.map { ($0.bird.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        print("🃏 [PredictionDebug]   Active migrating species: \(migratingBirdIds.count)")

        // 5. Score every nearby hotspot
        struct HotspotScore {
            let hotspot: Hotspot
            let migratingBirds: [(bird: Bird, weeks: [Int])]
            let distance: Double   // metres
            let score: Double      // higher = better
        }

        var scoredHotspots: [HotspotScore] = []

        for hotspot in nearbyHotspots {
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)

            // Query birds present at this hotspot (small radius — it's the hotspot itself)
            let birdsWithWeeks = await hotspotManager.getBirdsPresent(
                at: hotspotLoc,
                duringWeeks: weekRange,
                radiusInKm: 10.0
            )

            // Keep only actively migrating birds
            let migratingBirds = birdsWithWeeks.filter { migratingBirdIds.contains($0.bird.id) }
            guard !migratingBirds.isEmpty else {
                print("🃏 [PredictionDebug]   Hotspot '\(hotspot.name)': 0 migrating birds — skip")
                continue
            }

            let distance = locationService.distance(from: userLocation, to: hotspotLoc)
            // Score: prioritise species count, break ties by proximity
            let score = Double(migratingBirds.count) * 1_000.0 - distance

            print("🃏 [PredictionDebug]   Hotspot '\(hotspot.name)': \(migratingBirds.count) birds, \(Int(distance/1000))km, score \(Int(score))")
            scoredHotspots.append(HotspotScore(hotspot: hotspot, migratingBirds: migratingBirds, distance: distance, score: score))
        }

        // 6. Pick single best hotspot
        guard let top = scoredHotspots.max(by: { $0.score < $1.score }) else {
            print("⚠️ [PredictionDebug]   No hotspots with migrating birds found — returning empty")
            return []
        }
        print("🃏 [PredictionDebug]   Selected top hotspot: '\(top.hotspot.name)'")

        // 7. Build bird sub-cards
        let displayBirds: [BirdSpeciesDisplay] = top.migratingBirds.map { birdData in
            let bird = birdData.bird
            let weeks = birdData.weeks

            let badge: BirdSpeciesDisplay.StatusBadge
            if weeks.contains(currentWeek) {
                badge = BirdSpeciesDisplay.StatusBadge(
                    title: "Present",
                    subtitle: "Migrating",
                    iconName: "arrow.triangle.turn.up.right.circle.fill",
                    backgroundColorName: "systemGreen"
                )
            } else if let earliest = weeks.min(), earliest == currentWeek + 1 {
                badge = BirdSpeciesDisplay.StatusBadge(
                    title: "Arriving",
                    subtitle: "Next Week",
                    iconName: "calendar.badge.plus",
                    backgroundColorName: "systemBlue"
                )
            } else {
                let arrivalWeek = weeks.min() ?? (currentWeek + 2)
                badge = BirdSpeciesDisplay.StatusBadge(
                    title: "Coming Soon",
                    subtitle: "Week \(arrivalWeek)",
                    iconName: "clock.fill",
                    backgroundColorName: "systemOrange"
                )
            }

            let probability = top.hotspot.speciesList?
                .first(where: { $0.bird?.id == bird.id })?
                .probability ?? 70

            print("🃏 [PredictionDebug]     → \(bird.commonName), weeks: \(weeks), prob: \(probability)%")
            return BirdSpeciesDisplay(
                birdName: bird.commonName,
                birdImageName: bird.staticImageName,
                statusBadge: badge,
                sightabilityPercent: probability
            )
        }

        // 8. Pick primary bird (highest probability at this hotspot) for trajectory overlay
        let primaryBird = top.migratingBirds.max { a, b in
            let pa = top.hotspot.speciesList?.first(where: { $0.bird?.id == a.bird.id })?.probability ?? 0
            let pb = top.hotspot.speciesList?.first(where: { $0.bird?.id == b.bird.id })?.probability ?? 0
            return pa < pb
        }?.bird ?? top.migratingBirds[0].bird

        let primaryMigration = migrationsByBirdId[primaryBird.id]

        // 9. Distance string
        let distanceKm = Int(top.distance / 1000)
        let distanceString = distanceKm == 0 ? "Nearby" : "\(distanceKm) km"

        // 10. Assemble card models
        let topHotspotLoc = CLLocationCoordinate2D(latitude: top.hotspot.lat, longitude: top.hotspot.lon)
        let pinRadiusKm = 0.5
        let pinRadiusMeters = pinRadiusKm * 1000.0
        let areaOverlay = await resolveHotspotAreaOverlay(
            hotspotName: top.hotspot.name,
            hotspotCoordinate: topHotspotLoc,
            fallbackRadiusKm: 2.0
        )

        let migrationPrediction = MigrationPrediction(
            birdName: primaryBird.commonName,
            birdImageName: primaryBird.staticImageName,
            startLocation: primaryMigration?.paths.first.map {
                "(\(String(format: "%.2f", $0.lat)), \(String(format: "%.2f", $0.lon)))"
            } ?? "South",
            endLocation: primaryMigration?.paths.last.map {
                "(\(String(format: "%.2f", $0.lat)), \(String(format: "%.2f", $0.lon)))"
            } ?? "North",
            currentProgress: primaryMigration?.progress ?? 0.5,
            dateRange: "Weeks \(weekRange.first!)-\(weekRange.last!)",
            pathCoordinates: primaryMigration?.paths.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            } ?? []
        )

        let birdPins: [HotspotBirdSpot] = top.migratingBirds.map { birdData in
            let coordinate: CLLocationCoordinate2D

            if let migration = migrationsByBirdId[birdData.bird.id],
               let nearest = nearestTrajectoryCoordinate(
                to: topHotspotLoc,
                from: migration.paths
               ),
               nearest.distanceMeters <= pinRadiusMeters {
                coordinate = nearest.coordinate
            } else {
                // Ensure every displayed bird has a pin on this card.
                coordinate = topHotspotLoc
            }

            return HotspotBirdSpot(
                coordinate: coordinate,
                birdImageName: birdData.bird.staticImageName
            )
        }

        let hotspotPrediction = HotspotPrediction(
            placeName: top.hotspot.name,
            locationDetail: top.hotspot.locality ?? "Observation Point",
            weekNumber: formatWeekRangeDescription(startWeek: currentWeek, endWeek: weekRange.last ?? currentWeek),
            speciesCount: top.migratingBirds.count,
            distanceString: distanceString,
            dateRange: "Weeks \(weekRange.first!)-\(weekRange.last!)",
            placeImageName: top.hotspot.imageName ?? "placeholder_image",
            terrainTag: "Nature",
            seasonTag: seasonTag(for: weekRange),
            centerCoordinate: topHotspotLoc,
            pinRadiusKm: pinRadiusKm,
            areaOverlay: areaOverlay,
            hotspots: birdPins,
            birdSpecies: displayBirds
        )

        print("🃏 [PredictionDebug]   Final displayBirds count: \(displayBirds.count)")
        print("🃏 [PredictionDebug] Total DynamicMapCards created: 1")
        return [DynamicMapCard.combined(migration: migrationPrediction, hotspot: hotspotPrediction)]
    }

    func formatWeekDescription(week: Int) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = currentYear
        components.weekday = 2 // Monday
        
        guard let date = calendar.date(from: components) else {
            return "Week \(week)"
        }
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let monthName = monthFormatter.string(from: date)
        
        let day = calendar.component(.day, from: date)
        let weekInMonth: String
        if day <= 7 {
            weekInMonth = "1st week"
        } else if day <= 14 {
            weekInMonth = "2nd week"
        } else if day <= 21 {
            weekInMonth = "3rd week"
        } else if day <= 28 {
            weekInMonth = "4th week"
        } else {
            weekInMonth = "5th week"
        }
        
        return "\(monthName) \(weekInMonth)"
    }
    
    func formatWeekRangeDescription(startWeek: Int, endWeek: Int) -> String {
        let startText = formatWeekDescription(week: startWeek)
        let endText = formatWeekDescription(week: endWeek)
        if startText == endText {
            return startText
        }
        return "\(startText) - \(endText)"
    }

    private func nearestTrajectoryCoordinate(
        to center: CLLocationCoordinate2D,
        from paths: [TrajectoryPath]
    ) -> (coordinate: CLLocationCoordinate2D, distanceMeters: Double)? {
        var best: (coordinate: CLLocationCoordinate2D, distanceMeters: Double)?

        for path in paths {
            let coordinate = CLLocationCoordinate2D(latitude: path.lat, longitude: path.lon)
            let distance = locationService.distance(from: center, to: coordinate)

            if best == nil || distance < (best?.distanceMeters ?? .greatestFiniteMagnitude) {
                best = (coordinate: coordinate, distanceMeters: distance)
            }
        }

        return best
    }

    private func resolveHotspotAreaOverlay(
        hotspotName: String,
        hotspotCoordinate: CLLocationCoordinate2D,
        fallbackRadiusKm: Double
    ) async -> HotspotAreaOverlay {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = hotspotName
        request.region = MKCoordinateRegion(
            center: hotspotCoordinate,
            latitudinalMeters: 10_000,
            longitudinalMeters: 10_000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let nearestItem = nearestMapItem(to: hotspotCoordinate, from: response.mapItems)

            if let polygon = polygonCoordinates(
                from: response.boundingRegion,
                near: hotspotCoordinate,
                nearestResultCoordinate: nearestItem?.placemark.coordinate
            ) {
                return .polygon(coordinates: polygon)
            }

            if let mapItem = nearestItem,
               let circularRegion = mapItem.placemark.region as? CLCircularRegion {
                let radiusKm = max(0.2, circularRegion.radius / 1000.0)
                return .circle(radiusKm: radiusKm)
            }
        } catch {
            logger.log(error: error, context: "HomeManager.resolveHotspotAreaOverlay")
        }

        return .circle(radiusKm: fallbackRadiusKm)
    }

    private func nearestMapItem(
        to coordinate: CLLocationCoordinate2D,
        from items: [MKMapItem]
    ) -> MKMapItem? {
        items.min { first, second in
            let d1 = locationService.distance(from: coordinate, to: first.placemark.coordinate)
            let d2 = locationService.distance(from: coordinate, to: second.placemark.coordinate)
            return d1 < d2
        }
    }

    private func polygonCoordinates(
        from region: MKCoordinateRegion,
        near hotspotCoordinate: CLLocationCoordinate2D,
        nearestResultCoordinate: CLLocationCoordinate2D?
    ) -> [CLLocationCoordinate2D]? {
        let span = region.span
        guard span.latitudeDelta > 0.0001, span.longitudeDelta > 0.0001 else {
            return nil
        }

        let regionCenterDistanceKm = locationService.distance(
            from: hotspotCoordinate,
            to: region.center
        ) / 1000.0
        // Only trust the search bbox when it is anchored to the requested hotspot.
        guard regionCenterDistanceKm <= 1.0 else {
            return nil
        }

        if let nearestResultCoordinate {
            let nearestResultDistanceKm = locationService.distance(
                from: hotspotCoordinate,
                to: nearestResultCoordinate
            ) / 1000.0
            // Reject bbox if nearest search result itself is not close to hotspot.
            guard nearestResultDistanceKm <= 1.5 else {
                return nil
            }
        }

        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + span.latitudeDelta / 2,
            longitude: region.center.longitude - span.longitudeDelta / 2
        )
        let topRight = CLLocationCoordinate2D(
            latitude: region.center.latitude + span.latitudeDelta / 2,
            longitude: region.center.longitude + span.longitudeDelta / 2
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - span.latitudeDelta / 2,
            longitude: region.center.longitude + span.longitudeDelta / 2
        )
        let bottomLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude - span.latitudeDelta / 2,
            longitude: region.center.longitude - span.longitudeDelta / 2
        )

        let bboxCorners = [topLeft, topRight, bottomRight, bottomLeft]
        let maxCornerDistanceKm = bboxCorners
            .map { locationService.distance(from: hotspotCoordinate, to: $0) / 1000.0 }
            .max() ?? .greatestFiniteMagnitude

        // Discard broad regions; we only want tight local footprints on the card map.
        guard maxCornerDistanceKm <= 8 else {
            return nil
        }

        return [topLeft, topRight, bottomRight, bottomLeft]
    }
    
    private func seasonTag(for weeks: [Int]) -> String {
        guard !weeks.isEmpty else { return "Spring" }
        
        var counts: [String: Int] = [:]
        for week in weeks {
            let season = seasonForWeek(week)
            counts[season, default: 0] += 1
        }
        
        let startSeason = seasonForWeek(weeks[0])
        let maxCount = counts.values.max() ?? 0
        if counts[startSeason] == maxCount {
            return startSeason
        }
        return counts.first(where: { $0.value == maxCount })?.key ?? startSeason
    }
    
    private func seasonForWeek(_ week: Int) -> String {
        let normalizedWeek = ((week - 1) % 52) + 1
        
        switch normalizedWeek {
        case 10...20:
            return "Spring"
        case 21...26:
            return "Summer"
        case 27...39:
            return "Rainy"
        case 40...47:
            return "Autumn"
        default:
            return "Winter"
        }
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
    
    private func findNearbyHotspots(near location: CLLocationCoordinate2D, radiusKm: Double = 100.0) -> [Hotspot] {
        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.findNearbyHotspots")
            allHotspots = []
        }

        let radiusMeters = radiusKm * 1000

        let nearby = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            return locationService.distance(from: location, to: hotspotLoc) <= radiusMeters
        }

        // Sort closest first
        return nearby.sorted { h1, h2 in
            let d1 = locationService.distance(from: location, to: CLLocationCoordinate2D(latitude: h1.lat, longitude: h1.lon))
            let d2 = locationService.distance(from: location, to: CLLocationCoordinate2D(latitude: h2.lat, longitude: h2.lon))
            return d1 < d2
        }
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

    /// Returns birds present at the given location during ANY of the specified weeks,
    /// along with the sorted list of matching weeks for each bird.
    func getBirdsPresent(
        at location: CLLocationCoordinate2D,
        duringWeeks weeks: [Int],
        radiusInKm: Double = 50.0
    ) async -> [(bird: Bird, weeks: [Int])] {
        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try modelContext.fetch(descriptor)
        } catch {
            logger.log(error: error, context: "HotspotManager.getBirdsPresent(duringWeeks:)")
            allHotspots = []
        }

        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }

        var birdWeekMap: [UUID: Set<Int>] = [:]
        var birdMap: [UUID: Bird] = [:]

        for hotspot in nearbyHotspots {
            guard let speciesList = hotspot.speciesList else { continue }
            for presence in speciesList {
                guard let bird = presence.bird, let validWeeks = presence.validWeeks else { continue }
                let matchingWeeks = weeks.filter { validWeeks.contains($0) }
                guard !matchingWeeks.isEmpty else { continue }
                birdWeekMap[bird.id, default: []].formUnion(matchingWeeks)
                birdMap[bird.id] = bird
            }
        }

        return birdMap.values.map { bird in
            (bird: bird, weeks: Array(birdWeekMap[bird.id] ?? []).sorted())
        }
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
