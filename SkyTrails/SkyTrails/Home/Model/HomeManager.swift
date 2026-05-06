
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
    
    // Wrapper class because NSCache requires class types
    private final class SpeciesCacheItem {
        let response: HotspotPredictionResponse
        let cachedAt: Date = Date()
        init(response: HotspotPredictionResponse) { self.response = response }
    }

    // App-Side Memory Cache: Makes hotspot card clicks instant within one session
    private let speciesMemoryCache: NSCache<NSString, SpeciesCacheItem> = {
        let cache = NSCache<NSString, SpeciesCacheItem>()
        cache.countLimit = 50 
        return cache
    }()
    private var spotPredictionMemoryCache: [String: [FinalPredictionResult]] = [:]

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
    func getHomeScreenData(
        userLocation: CLLocationCoordinate2D? = nil
    ) async -> HomeScreenData {
        
        let location = userLocation ?? LocationPreferences.shared.homeLocation
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
        async let observations: [CommunityObservation] = {
            do {
                return try await getRecentObservations(near: location)
            } catch {
                await logger.log(error: error, context: "HomeManager.getHomeScreenData.observations")
                return []
            }
        }()
        async let news = newsService.fetchNews()

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
            observations,
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
    }
    
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

        // Priority 1: regional_trends grid table
        do {
            let trendItems = try await SkyTrailsAPIService.shared.fetchRegionalTrends(
                lat: userLocation.latitude,
                lon: userLocation.longitude,
                week: week
            )
            if !trendItems.isEmpty {
                return trendItems.prefix(limit).compactMap { item in
                    guard let bird = watchlistManager.findBird(byName: item.name) else { return nil }
                    return RecommendedBirdResult(
                        bird: bird,
                        dateRange: formatWeekDescription(week: week)
                    )
                }
            }
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedBirds.regionalTrends")
        }

        // Priority 2: Edge Function
        do {
            let response = try await fetchNearbyHotspotCardFromEdge(near: userLocation)
            let predictions = response.card?.species ?? []
            if !predictions.isEmpty {
                return predictions.prefix(limit).compactMap { species in
                    guard let bird = watchlistManager.findBird(byName: species.commonName) else { return nil }
                    return RecommendedBirdResult(
                        bird: bird,
                        dateRange: species.weekNumber ?? formatWeekDescription(week: week)
                    )
                }
            }
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedBirds.edge")
        }

        // Fallback: local SwiftData store
        return await getRecommendedBirdsFromLocal(userLocation: userLocation, currentWeek: week, radiusInKm: radiusInKm, limit: limit)
    }

    private func getRecommendedBirdsFromLocal(
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
        let locationBirdIds = Set(birdsAtLocation.map { $0.bird_id })
        
        for entry in watchlistEntries {
            guard let bird = entry.bird else { continue }
            
            if locationBirdIds.contains(bird.bird_id) {
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
    
    func getWatchlistSpots() async -> [PopularSpotResult] {
        let watchlists = (try? watchlistManager.fetchWatchlists()) ?? []
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        var results: [PopularSpotResult] = []

        for watchlist in watchlists {
            guard let location = watchlist.location,
                  let coordinate = locationService.parseCoordinate(from: location) else {
                continue
            }

            let radiusKm = 5.0
            let birdCount = await getActiveSpeciesCount(
                at: coordinate,
                duringWeek: currentWeek,
                radiusInKm: radiusKm
            )
            let observedCount = watchlist.entries?.filter { $0.status == .observed }.count ?? 0

            let result = PopularSpotResult(
                id: watchlist.watchlist_id,
                title: watchlist.title ?? "Unnamed Spot",
                location: watchlist.locationDisplayName ?? location,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                speciesCount: birdCount,
                observedCount: observedCount,
                radius: radiusKm,
                imageName: watchlist.coverImagePath,
                edgeSpecies: nil,
                hotspotId: nil
            )
            results.append(result)
        }

        return results
    }
    
    func getRecommendedSpots(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 100.0,
        limit: Int = 5
    ) async -> [PopularSpotResult] {
        // Priority 1: grid_hotspots table (pre-computed, no Edge Function cold-start)
        do {
            if let gridRow = try await SkyTrailsAPIService.shared.fetchGridHotspots(
                lat: location.latitude,
                lon: location.longitude
            ), !gridRow.hotspots.isEmpty {
                let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
                let regionalSpecies = (try? await SkyTrailsAPIService.shared.fetchRegionalTrends(
                    lat: location.latitude,
                    lon: location.longitude,
                    week: currentWeek
                )) ?? []
                let preliminarySpecies = edgeSpecies(from: regionalSpecies, week: currentWeek)

                return gridRow.hotspots.prefix(limit).map { item in
                    PopularSpotResult(
                        id: UUID(uuidString: item.hotspot_id) ?? UUID(),
                        title: item.name,
                        location: "Nearby",
                        latitude: item.lat,
                        longitude: item.lon,
                        speciesCount: item.checklist_count,
                        observedCount: 0,
                        radius: 5.0,
                        imageName: nil,
                        edgeSpecies: preliminarySpecies,
                        distanceKm: nil,
                        hotspotId: item.hotspot_id
                    )
                }
            }
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedSpots.gridHotspots")
        }

        // Priority 2: Edge Function (enriched species data)
        do {
            let response = try await fetchNearbyHotspotCardFromEdge(near: location)
            if !response.nearbyHotspots.isEmpty {
                return response.nearbyHotspots.map { mapHotspotToPopularSpot($0) }
            }
            // Priority 3: hotspots_geo REST table
            let supabaseHotspots = try await SkyTrailsAPIService.shared.fetchLocationsFromSupabase(near: location)
            return supabaseHotspots.map { mapHotspotToPopularSpot($0) }
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedSpots.hybrid")
        }

        // Fallback: local SwiftData store
        return await getRecommendedSpotsFromLocalStore(near: location, radiusInKm: radiusInKm, limit: limit)
    }

    /// Fetches species for a specific hotspot coordinate from the grid_hotspots table.
    /// Used by HomeViewController for async spot-tap navigation.
    func getSpeciesForHotspot(lat: Double, lon: Double, hotspotId: String?) async -> [FinalPredictionResult] {
        let cacheKey = hotspotSpeciesCacheKey(lat: lat, lon: lon, hotspotId: hotspotId)
        if let cached = spotPredictionMemoryCache[cacheKey] {
            return cached
        }

        do {
            let config = try SupabaseConfig.load()
            
            guard var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false) else {
                return []
            }
            components.path = "/functions/v1/get-nearby-birds"
            
            guard let url = components.url else { return [] }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 8
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            var body: [String: Any] = ["lat": lat, "lng": lon]
            if let hotspotId = hotspotId {
                body["hotspotId"] = hotspotId
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                return []
            }
            
            struct EdgeResponse: Decodable {
                struct Hotspot: Decodable {
                    struct Species: Decodable {
                        let ebirdSpeciesCode: String?
                        let commonName: String
                        let imageName: String?
                        let probability: Int
                        let residencyStatus: String
                        let weekNumber: String?
                    }
                    let species: [Species]
                }
                let card: Hotspot?
            }
            
            let decoded = try JSONDecoder().decode(EdgeResponse.self, from: data)
            let species = decoded.card?.species ?? []
            
            let results = species.map { sp in
                let bird = watchlistManager.findBird(byName: sp.commonName)
                
                let rawImage = sp.imageName
                let cleanImage = (rawImage == nil || 
                                  rawImage == "placeholder_bird" || 
                                  rawImage == "placeholder_image" || 
                                  rawImage?.isEmpty == true) ? nil : rawImage

                let remoteImage = cleanImage ?? bird?.imageUrl ?? bird?.staticImageName

                return FinalPredictionResult(
                    birdName: sp.commonName,
                    imageName: remoteImage ?? "placeholder_image",
                    likelySpot: "Nearby hotspot",
                    matchedInputIndex: 0,
                    matchedLocation: (lat: lat, lon: lon),
                    spottingProbability: sp.probability,
                    weekNumber: sp.weekNumber ?? "This week",
                    residencyStatus: sp.residencyStatus,
                    ebirdSpeciesCode: sp.ebirdSpeciesCode
                )
            }
            if !results.isEmpty {
                spotPredictionMemoryCache[cacheKey] = results
            }
            return results
        } catch {
            logger.log(error: error, context: "HomeManager.getSpeciesForHotspot")
            return []
        }
    }

    private func hotspotSpeciesCacheKey(lat: Double, lon: Double, hotspotId: String?) -> String {
        if let hotspotId, !hotspotId.isEmpty {
            return "hotspot:\(hotspotId)"
        }
        return "coord:\(String(format: "%.4f", lat)),\(String(format: "%.4f", lon))"
    }

    private func edgeSpecies(from trendItems: [RegionalTrendSpeciesItem], week: Int) -> [NearbyHotspotEdgeSpecies] {
        let weekText = formatWeekDescription(week: week)
        return trendItems.prefix(50).map { item in
            NearbyHotspotEdgeSpecies(
                commonName: item.name,
                scientificName: nil,
                imageName: watchlistManager.findBird(byName: item.name)?.staticImageName,
                probability: max(1, min(100, Int((item.score * 100).rounded()))),
                weekNumber: weekText,
                residencyStatus: "Expected",
                ebirdSpeciesCode: item.id
            )
        }
    }

    private func mapHotspotToPopularSpot(_ item: HotspotModel) -> PopularSpotResult {
        // Find the first available bird image from the species list to use as the card thumbnail
        let topBirdImage = item.species?.first(where: { !($0.imageName ?? "").isEmpty })?.imageName
        
        return PopularSpotResult(
            id: UUID(uuidString: item.hotspotId) ?? UUID(),
            title: item.placeName,
            location: item.locationDetail,
            latitude: item.center.lat,
            longitude: item.center.lng,
            speciesCount: item.speciesCount,
            observedCount: 0,
            radius: 5.0,
            imageName: topBirdImage ?? "placeholder_image",
            edgeSpecies: item.species?.map { 
                NearbyHotspotEdgeSpecies(
                    commonName: $0.commonName, 
                    scientificName: $0.scientificName, 
                    imageName: $0.imageName, 
                    probability: $0.likelihood, 
                    weekNumber: $0.weekNumber ?? "Current Week", 
                    residencyStatus: $0.residencyStatus.rawValue,
                    ebirdSpeciesCode: $0.ebirdSpeciesCode
                ) 
            },
            distanceKm: item.distanceKm,
            hotspotId: item.hotspotId
        )
    }

    private func getActiveSpeciesCount(
        at location: CLLocationCoordinate2D,
        duringWeek week: Int,
        radiusInKm: Double
    ) async -> Int {
        let birds = await hotspotManager.getBirdsPresent(
            at: location,
            duringWeek: week,
            radiusInKm: radiusInKm
        )
        return birds.count
    }
    
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
        guard let userLocation = userLocation ?? locationService.currentLocation else {
            return []
        }
        
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        
        // Try regional trends first — shows "Your Area" card
        do {
            let trendSpecies = try await SkyTrailsAPIService.shared.fetchRegionalTrends(
                lat: userLocation.latitude,
                lon: userLocation.longitude,
                week: currentWeek
            )
            if !trendSpecies.isEmpty {
                if let card = await mapRegionalTrendsToDynamicMapCard(
                    species: trendSpecies,
                    userLocation: userLocation
                ) {
                    return [card]
                }
            }
        } catch {
            logger.log(error: error, context: "HomeManager.getDynamicMapCards.trends")
        }
        
        // Fallback to edge function card
        do {
            let edgeResponse = try await fetchNearbyHotspotCardFromEdge(near: userLocation)
            if let edgeCard = edgeResponse.card,
               let mappedCard = await mapEdgeCardToDynamicMapCard(edgeCard, userLocation: userLocation) {
                return [mappedCard]
            }
        } catch {
            logger.log(error: error, context: "HomeManager.getDynamicMapCards.edge")
        }
        
        return await getDynamicMapCardsFromLocal(userLocation: userLocation)
    }

    private func mapRegionalTrendsToDynamicMapCard(
        species: [RegionalTrendSpeciesItem],
        userLocation: CLLocationCoordinate2D
    ) async -> DynamicMapCard? {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let coordinate = userLocation
        
        let displaySpecies: [BirdSpeciesDisplay] = species.prefix(8).map { sp in
            let bird = watchlistManager.findBird(byName: sp.name)
            let rawImage = bird?.imageUrl ?? bird?.staticImageName
            
            let normalizedName = sp.name.lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "-", with: "_")
            
            let finalImageName = rawImage ?? normalizedName
            
            return BirdSpeciesDisplay(
                birdName: sp.name,
                birdImageName: finalImageName.isEmpty ? "placeholder_image" : finalImageName,
                statusBadge: BirdSpeciesDisplay.StatusBadge(
                    title: "Present",
                    subtitle: "Expected",
                    iconName: "bird.circle.fill",
                    backgroundColorName: "systemGreen"
                ),
                sightabilityPercent: Int(sp.score * 100),
                weekNumber: "Week \(currentWeek)",
                residencyStatus: "Expected",
                ebirdSpeciesCode: sp.id
            )
        }
        
        // Reverse geocode to get precise location name
        var locationTitle = "Your Area"
        var locationDetail = "Species trending near you"
        
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(
            latitude: userLocation.latitude, 
            longitude: userLocation.longitude
        )
        if let placemarks = try? await geocoder.reverseGeocodeLocation(clLocation),
           let placemark = placemarks.first {
            
            // 1. Exact place name for the title
            // name typically contains "123 Main St" or the name of a business/landmark
            // If that's too specific, thoroughfare (street) + subLocality (neighborhood) works well
            locationTitle = placemark.name 
                         ?? placemark.thoroughfare 
                         ?? placemark.subLocality 
                         ?? placemark.locality 
                         ?? "Your Area"
            
            // 2. City, State, Country for the subtitle
            let city = placemark.locality
            let state = placemark.administrativeArea
            let country = placemark.country
            
            let components = [city, state, country].compactMap { $0 }
            if !components.isEmpty {
                locationDetail = components.joined(separator: ", ")
            }
        }

        let areaOverlay = await resolveHotspotAreaOverlay(
            hotspotName: locationTitle,
            hotspotCoordinate: coordinate,
            fallbackRadiusKm: 2.0
        )
        
        let migrationPrediction = MigrationPrediction(
            birdName: displaySpecies.first?.birdName ?? "Local Birds",
            birdImageName: displaySpecies.first?.birdImageName ?? "placeholder_image",
            startLocation: "Nearby",
            endLocation: locationTitle,
            currentProgress: 1.0,
            dateRange: "Week \(currentWeek)",
            pathCoordinates: []
        )
        
        let hotspotPrediction = HotspotPrediction(
            placeName: locationTitle,
            locationDetail: locationDetail,
            weekNumber: "Week \(currentWeek)",
            speciesCount: displaySpecies.count,
            distanceString: "Nearby",
            dateRange: "Week \(currentWeek)",
            placeImageName: "placeholder_image",
            terrainTag: "Nature",
            seasonTag: seasonTag(for: [currentWeek]),
            centerCoordinate: coordinate,
            pinRadiusKm: 2.0,
            areaOverlay: areaOverlay,
            hotspots: displaySpecies.prefix(5).map {
                HotspotBirdSpot(coordinate: coordinate, birdImageName: $0.birdImageName)
            },
            birdSpecies: displaySpecies
        )
        
        return .combined(migration: migrationPrediction, hotspot: hotspotPrediction)
    }

    private func mapEdgeCardToDynamicMapCard(
        _ card: HotspotModel,
        userLocation: CLLocationCoordinate2D
    ) async -> DynamicMapCard? {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let coordinate = CLLocationCoordinate2D(latitude: card.center.lat, longitude: card.center.lng)
        
        let displaySpecies: [BirdSpeciesDisplay] = (card.species ?? []).prefix(8).map { species in
            let fallbackBird = watchlistManager.findBird(byName: species.commonName)
            
            let rawImage = species.imageName
            let cleanImage = (rawImage == nil || 
                              rawImage == "placeholder_bird" || 
                              rawImage == "placeholder_image" || 
                              rawImage?.isEmpty == true) ? nil : rawImage

            let remoteImage = cleanImage ?? fallbackBird?.imageUrl ?? fallbackBird?.staticImageName

            let normalizedName = species.commonName.lowercased()
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "-", with: "_")
            
            let finalImageName = remoteImage ?? normalizedName
            let statusText = species.residencyStatus.rawValue

            return BirdSpeciesDisplay(
                birdName: species.commonName,
                birdImageName: finalImageName.isEmpty ? "placeholder_image" : finalImageName,
                statusBadge: BirdSpeciesDisplay.StatusBadge(
                    title: "Present",
                    subtitle: statusText,
                    iconName: "bird.circle.fill",
                    backgroundColorName: "systemGreen"
                ),
                sightabilityPercent: species.likelihood,
                weekNumber: species.weekNumber ?? card.weekNumber ?? "Current Week",
                residencyStatus: statusText,
                ebirdSpeciesCode: species.ebirdSpeciesCode
            )
        }

        let fallbackSpecies = displaySpecies.isEmpty
            ? [
                BirdSpeciesDisplay(
                    birdName: "Recent Birds",
                    birdImageName: "placeholder_image",
                    statusBadge: BirdSpeciesDisplay.StatusBadge(
                        title: "Nearby",
                        subtitle: "Birding Spot",
                        iconName: "bird.circle.fill",
                        backgroundColorName: "systemGreen"
                    ),
                    sightabilityPercent: 60,
                    weekNumber: card.weekNumber ?? formatWeekDescription(week: currentWeek),
                    residencyStatus: "Check nearby sightings",
                    ebirdSpeciesCode: nil
                )
            ]
            : displaySpecies

        let resolvedDistanceString: String = {
            if !card.distanceString.isEmpty {
                return card.distanceString
            }
            let distanceKm = Int(locationService.distance(from: userLocation, to: coordinate) / 1000.0)
            return distanceKm == 0 ? "Nearby" : "\(distanceKm) km"
        }()

        let primaryBird = fallbackSpecies.first?.birdName ?? "Nearby Birds"
        let primaryImage = fallbackSpecies.first?.birdImageName ?? "placeholder_image"
        let weekText = card.weekNumber ?? formatWeekDescription(week: currentWeek)
        let areaOverlay = await resolveHotspotAreaOverlay(
            hotspotName: card.placeName,
            hotspotCoordinate: coordinate,
            fallbackRadiusKm: 2.0
        )

        let migrationPrediction = MigrationPrediction(
            birdName: primaryBird,
            birdImageName: primaryImage,
            startLocation: "Nearby",
            endLocation: card.placeName,
            currentProgress: 1.0,
            dateRange: weekText,
            pathCoordinates: []
        )

        let hotspotPrediction = HotspotPrediction(
            placeName: card.placeName,
            locationDetail: card.locationDetail,
            weekNumber: weekText,
            speciesCount: fallbackSpecies.count,
            distanceString: resolvedDistanceString,
            dateRange: weekText,
            placeImageName: "placeholder_image",
            terrainTag: "Nature",
            seasonTag: seasonTag(for: [currentWeek]),
            centerCoordinate: coordinate,
            pinRadiusKm: 0.5,
            areaOverlay: areaOverlay,
            hotspots: fallbackSpecies.prefix(5).map {
                HotspotBirdSpot(coordinate: coordinate, birdImageName: $0.birdImageName)
            },
            birdSpecies: fallbackSpecies
        )

        return .combined(migration: migrationPrediction, hotspot: hotspotPrediction)
    }

    private func getDynamicMapCardsFromLocal(userLocation: CLLocationCoordinate2D) async -> [DynamicMapCard] {
        let nearbyHotspots = findNearbyHotspots(near: userLocation, radiusKm: 100.0)
        guard !nearbyHotspots.isEmpty else {
            return []
        }
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let weekRange = (currentWeek...(currentWeek + 4)).map { ($0 - 1) % 52 + 1 }
        let migrations = await getActiveMigrations()
        let migratingBirdIds = Set(migrations.compactMap { $0.bird.bird_id })
        let migrationsByBirdId: [UUID: MigrationCardResult] = Dictionary(
            migrations.map { ($0.bird.bird_id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        struct HotspotScore {
            let hotspot: Hotspot
            let migratingBirds: [(bird: Bird, weeks: [Int])]
            let distance: Double
            let score: Double
        }

        var scoredHotspots: [HotspotScore] = []

        for hotspot in nearbyHotspots {
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            let birdsWithWeeks = await hotspotManager.getBirdsPresent(
                at: hotspotLoc,
                duringWeeks: weekRange,
                radiusInKm: 10.0
            )
            let migratingBirds = birdsWithWeeks.filter { migratingBirdIds.contains($0.bird.bird_id) }
            guard !migratingBirds.isEmpty else {
                continue
            }

            let distance = locationService.distance(from: userLocation, to: hotspotLoc)
            let score = Double(migratingBirds.count) * 1_000.0 - distance
            scoredHotspots.append(HotspotScore(hotspot: hotspot, migratingBirds: migratingBirds, distance: distance, score: score))
        }
        guard let top = scoredHotspots.max(by: { $0.score < $1.score }) else {
            return []
        }
        let displayBirds: [BirdSpeciesDisplay] = top.migratingBirds.map { birdData in
            let bird = birdData.bird
            let weeks = birdData.weeks

            let hotspotPresence = top.hotspot.speciesList?.first(where: { $0.bird?.bird_id == bird.bird_id })
            let isResident = (hotspotPresence?.validWeeks?.count ?? 0) >= 52
            let status: String
            if isResident {
                status = "Resident/Local"
            } else if hotspotPresence?.validWeeks?.contains(currentWeek) ?? false {
                status = "Present"
            } else {
                status = "Migrating"
            }

            let weekNum = weeks.first ?? currentWeek
            let weekText = formatWeekDescription(week: weekNum)

            let badge: BirdSpeciesDisplay.StatusBadge
            if hotspotPresence?.validWeeks?.contains(currentWeek) ?? false {
                badge = BirdSpeciesDisplay.StatusBadge(
                    title: "Present",
                    subtitle: status,
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

            let speciesPresence = top.hotspot.speciesList?
                .first(where: { $0.bird?.bird_id == bird.bird_id })
            let probability = sightabilityProbability(
                from: speciesPresence,
                preferredWeeks: weekRange,
                currentWeek: currentWeek,
                fallback: 70
            )
            return BirdSpeciesDisplay(
                birdName: bird.commonName,
                birdImageName: bird.staticImageName,
                statusBadge: badge,
                sightabilityPercent: probability,
                weekNumber: weekText,
                residencyStatus: status,
                ebirdSpeciesCode: nil
            )
        }
        let primaryBird = top.migratingBirds.max { a, b in
            let pa = sightabilityProbability(
                from: top.hotspot.speciesList?.first(where: { $0.bird?.bird_id == a.bird.bird_id }),
                preferredWeeks: weekRange,
                currentWeek: currentWeek,
                fallback: 0
            )
            let pb = sightabilityProbability(
                from: top.hotspot.speciesList?.first(where: { $0.bird?.bird_id == b.bird.bird_id }),
                preferredWeeks: weekRange,
                currentWeek: currentWeek,
                fallback: 0
            )
            return pa < pb
        }?.bird ?? top.migratingBirds[0].bird

        let primaryMigration = migrationsByBirdId[primaryBird.bird_id]
        let distanceKm = Int(top.distance / 1000)
        let distanceString = distanceKm == 0 ? "Nearby" : "\(distanceKm) km"
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

            if let migration = migrationsByBirdId[birdData.bird.bird_id],
               let nearest = nearestTrajectoryCoordinate(
                to: topHotspotLoc,
                from: migration.paths
               ),
               nearest.distanceMeters <= pinRadiusMeters {
                coordinate = nearest.coordinate
            } else {
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
        return [DynamicMapCard.combined(migration: migrationPrediction, hotspot: hotspotPrediction)]
    }

    private func edgeDisplaySpecies(
        for card: NearbyHotspotEdgeCard,
        coordinate: CLLocationCoordinate2D,
        currentWeek: Int
    ) async -> [BirdSpeciesDisplay] {
        if let edgeSpecies = card.species, !edgeSpecies.isEmpty {
            return edgeSpecies.prefix(8).map { species in
                let fallbackBird = watchlistManager.findBird(byName: species.commonName)
                
                // Construct a normalized image name from the common name as the ultimate fallback
                let normalizedName = species.commonName.lowercased()
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "-", with: "_")
                
                let imageName = species.imageName
                    ?? fallbackBird?.staticImageName
                    ?? normalizedName

                let finalImageName = imageName.isEmpty ? "placeholder_image" : imageName
                let statusText = species.residencyStatus ?? "Recently observed"

                return BirdSpeciesDisplay(
                    birdName: species.commonName,
                    birdImageName: finalImageName,
                    statusBadge: BirdSpeciesDisplay.StatusBadge(
                        title: "Present",
                        subtitle: statusText,
                        iconName: "bird.circle.fill",
                        backgroundColorName: "systemGreen"
                    ),
                    sightabilityPercent: species.probability ?? 70,
                    weekNumber: species.weekNumber ?? card.weekNumber ?? formatWeekDescription(week: currentWeek),
                    residencyStatus: statusText,
                    ebirdSpeciesCode: species.ebirdSpeciesCode
                    )            }
        }

        let localBirds = await hotspotManager.getBirdsPresent(
            at: coordinate,
            duringWeek: currentWeek,
            radiusInKm: 10.0
        )

        return Array(localBirds.prefix(8)).map { bird in
            return BirdSpeciesDisplay(
                birdName: bird.commonName,
                birdImageName: bird.staticImageName.isEmpty ? "placeholder_image" : bird.staticImageName,
                statusBadge: BirdSpeciesDisplay.StatusBadge(
                    title: "Present",
                    subtitle: "Nearby",
                    iconName: "bird.circle.fill",
                    backgroundColorName: "systemGreen"
                ),
                sightabilityPercent: 70,
                weekNumber: card.weekNumber ?? formatWeekDescription(week: currentWeek),
                residencyStatus: "Recently observed",
                ebirdSpeciesCode: nil
            )
        }
    }

    func formatWeekDescription(week: Int) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var components = DateComponents()
        components.weekOfYear = week
        components.yearForWeekOfYear = currentYear
        components.weekday = 2
        
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

            if let mapItem = nearestItem {
                let distanceMeters = CLLocation(latitude: hotspotCoordinate.latitude, longitude: hotspotCoordinate.longitude)
                    .distance(from: mapItem.location)
                let radiusKm = max(0.2, min(5.0, distanceMeters / 1000.0))
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
            let d1 = locationService.distance(from: coordinate, to: first.location.coordinate)
            let d2 = locationService.distance(from: coordinate, to: second.location.coordinate)
            return d1 < d2
        }
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
    
    private func calculateProgress(currentWeek: Int, startWeek: Int, endWeek: Int) -> Float {
        let totalWeeks = endWeek - startWeek
        guard totalWeeks > 0 else { return 0.5 }
        let elapsed = currentWeek - startWeek
        return Float(elapsed) / Float(totalWeeks)
    }

    private func sightabilityProbability(
        from presence: HotspotSpeciesPresence?,
        preferredWeeks: [Int],
        currentWeek: Int,
        fallback: Int
    ) -> Int {
        guard let presence else { return fallback }

        if let validWeeks = presence.validWeeks,
           let weeklyProbabilities = presence.weeklyProbabilities,
           validWeeks.count == weeklyProbabilities.count,
           !validWeeks.isEmpty {
            let weekToProbability = Dictionary(uniqueKeysWithValues: zip(validWeeks, weeklyProbabilities))

            let orderedCandidates = [currentWeek] + preferredWeeks
            for week in orderedCandidates {
                if let probability = weekToProbability[week] {
                    return probability
                }
            }

            if let firstWeek = validWeeks.first,
               let firstProbability = weekToProbability[firstWeek] {
                return firstProbability
            }
        }

        return presence.probability ?? fallback
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
               let presence = speciesList.first(where: { $0.bird?.bird_id == bird.bird_id }),
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

    func yearlySightabilitySeries(
        forBirdNamed birdName: String,
        near location: CLLocationCoordinate2D,
        searchRadiusKm: Double = 50.0
    ) -> [Int] {
        let birdDescriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { bird in
                bird.commonName == birdName
            }
        )

        let bird: Bird?
        do {
            bird = try watchlistManager.fetchOne(Bird.self, descriptor: birdDescriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.yearlySightabilitySeries.fetchBird")
            bird = nil
        }

        guard let bird else { return Array(repeating: 0, count: 52) }

        let hotspotDescriptor = FetchDescriptor<Hotspot>()
        let hotspots: [Hotspot]
        do {
            hotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: hotspotDescriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.yearlySightabilitySeries.fetchHotspots")
            return Array(repeating: 0, count: 52)
        }

        let radiusMeters = searchRadiusKm * 1000.0
        let nearestPresence = hotspots
            .compactMap { hotspot -> (presence: HotspotSpeciesPresence, distance: Double)? in
                guard let presence = hotspot.speciesList?.first(where: { $0.bird?.bird_id == bird.bird_id }) else { return nil }
                let coord = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
                let distance = locationService.distance(from: location, to: coord)
                guard distance <= radiusMeters else { return nil }
                return (presence: presence, distance: distance)
            }
            .min(by: { $0.distance < $1.distance })?
            .presence

        guard let presence = nearestPresence else {
            return Array(repeating: 0, count: 52)
        }

        var result = Array(repeating: 0, count: 52)

        if let validWeeks = presence.validWeeks,
           let weeklyProbabilities = presence.weeklyProbabilities,
           validWeeks.count == weeklyProbabilities.count {
            for (week, value) in zip(validWeeks, weeklyProbabilities) where (1...52).contains(week) {
                result[week - 1] = min(100, max(0, value))
            }
            return result
        }

        if let validWeeks = presence.validWeeks,
           let probability = presence.probability {
            let clamped = min(100, max(0, probability))
            for week in validWeeks where (1...52).contains(week) {
                result[week - 1] = clamped
            }
        }

        return result
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

    private func fetchNearbyHotspotCardFromEdge(
        near location: CLLocationCoordinate2D
    ) async throws -> HotspotPredictionResponse {
        let cacheKey = "\(String(format: "%.4f", location.latitude)),\(String(format: "%.4f", location.longitude))" as NSString
        
        // Check Memory Cache first (Session-based "Memory")
        if let cached = speciesMemoryCache.object(forKey: cacheKey) {
            // Expire after 30 minutes
            if Date().timeIntervalSince(cached.cachedAt) < 1800 {
                return cached.response
            } else {
                speciesMemoryCache.removeObject(forKey: cacheKey)
            }
        }

        // Check Location Cache Metadata (The 5km / 6-Hour Rule)
        let clLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        if !LocationCacheManager.shared.shouldRefreshData(currentLocation: clLoc) {
            // Logic for potential disk cache could go here
        }

        let response = try await SkyTrailsAPIService.shared.fetchPredictions(lat: location.latitude, lng: location.longitude)
        
        // Save to Memory Cache (Wrap in class)
        speciesMemoryCache.setObject(SpeciesCacheItem(response: response), forKey: cacheKey)
        LocationCacheManager.shared.updateCacheMetadata(location: clLoc)
        
        return response
    }

    private func getRecommendedSpotsFromLocalStore(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double,
        limit: Int
    ) async -> [PopularSpotResult] {
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())

        let descriptor = FetchDescriptor<Hotspot>()
        let allHotspots: [Hotspot]
        do {
            allHotspots = try watchlistManager.fetchAll(Hotspot.self, descriptor: descriptor)
        } catch {
            logger.log(error: error, context: "HomeManager.getRecommendedSpots")
            return []
        }

        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            return locationService.distance(from: location, to: hotspotLoc) <= (radiusInKm * 1000)
        }

        let watchlistSpotNames = Set((try? watchlistManager.fetchWatchlists())?.compactMap { $0.location } ?? [])
        let recommended = nearbyHotspots
            .filter { !watchlistSpotNames.contains($0.name) }
            .prefix(limit)

        var results: [PopularSpotResult] = []
        for hotspot in recommended {
            let hotspotLoc = CLLocationCoordinate2D(latitude: hotspot.lat, longitude: hotspot.lon)
            let cardRadiusKm = 5.0
            let speciesCount = await getActiveSpeciesCount(
                at: hotspotLoc,
                duringWeek: currentWeek,
                radiusInKm: cardRadiusKm
            )
            let distance = locationService.distance(from: location, to: hotspotLoc)

            results.append(
                PopularSpotResult(
                    id: hotspot.id,
                    title: hotspot.name,
                    location: hotspot.locality ?? "Unknown",
                    latitude: hotspot.lat,
                    longitude: hotspot.lon,
                    speciesCount: speciesCount,
                    observedCount: 0,
                    radius: cardRadiusKm,
                    imageName: hotspot.imageName,
                    edgeSpecies: nil,
                    distanceKm: distance / 1000.0,
                    hotspotId: nil
                )
            )
        }

        return results
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
        return nearby.sorted { h1, h2 in
            let d1 = locationService.distance(from: location, to: CLLocationCoordinate2D(latitude: h1.lat, longitude: h1.lon))
            let d2 = locationService.distance(from: location, to: CLLocationCoordinate2D(latitude: h2.lat, longitude: h2.lon))
            return d1 < d2
        }
    }

    func getLivePredictions(for lat: Double, lon: Double, radiusKm: Double) async -> [FinalPredictionResult] {
        let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        let weekRange = (currentWeek...(currentWeek + 4)).map { ($0 - 1) % 52 + 1 }
        
        let birdsWithWeeks = await hotspotManager.getBirdsPresent(
            at: location,
            duringWeeks: weekRange,
            radiusInKm: radiusKm
        )
        let nearbyHotspots = findNearbyHotspots(near: location, radiusKm: radiusKm)
        
        return birdsWithWeeks.map { birdData in
            let bird = birdData.bird
            let matchingWeeks = birdData.weeks
            let matchingPresence = nearbyHotspots
                .compactMap { hotspot in
                    hotspot.speciesList?.first(where: { $0.bird?.bird_id == bird.bird_id })
                }
            
            let probability = matchingPresence
                .map {
                    sightabilityProbability(
                        from: $0,
                        preferredWeeks: [currentWeek],
                        currentWeek: currentWeek,
                        fallback: 70
                    )
                }
                .max() ?? 70
            let weekNum = matchingWeeks.first ?? currentWeek
            let weekText = formatWeekDescription(week: weekNum)
            let isResident = matchingPresence.contains(where: { ($0.validWeeks?.count ?? 0) >= 52 })
            let status: String
            if isResident {
                status = "Local"
            } else if matchingWeeks.contains(currentWeek) {
                status = "Present"
            } else {
                status = "Migrating"
            }

            return FinalPredictionResult(
                birdName: bird.commonName,
                imageName: bird.imageUrl ?? bird.staticImageName,
                likelySpot: bird.likelySpot ?? "Sky",
                matchedInputIndex: 0,
                matchedLocation: (lat: lat, lon: lon),
                spottingProbability: probability,
                weekNumber: weekText,
                residencyStatus: status,
                ebirdSpeciesCode: bird.ebird_species_code
            )
        }
    }

    func predictionResults(
        from edgeSpecies: [NearbyHotspotEdgeSpecies],
        lat: Double,
        lon: Double
    ) -> [FinalPredictionResult] {
        let allBirds = watchlistManager.fetchAllBirds()
        let birdMap = Dictionary(allBirds.map { ($0.commonName, $0) }, uniquingKeysWith: { first, _ in first })


        return edgeSpecies.map { species in
            let bird = birdMap[species.commonName]
            
            let rawImage = species.imageName
            let cleanImage = (rawImage == nil || 
                              rawImage == "placeholder_bird" || 
                              rawImage == "placeholder_image" || 
                              rawImage?.isEmpty == true) ? nil : rawImage

            let remoteImage = cleanImage ?? bird?.imageUrl ?? bird?.staticImageName


            return FinalPredictionResult(
                birdName: species.commonName,
                imageName: remoteImage ?? "placeholder_image",
                likelySpot: "Nearby hotspot",
                matchedInputIndex: 0,
                matchedLocation: (lat: lat, lon: lon),
                spottingProbability: species.probability ?? 70,
                weekNumber: species.weekNumber,
                residencyStatus: species.residencyStatus,
                ebirdSpeciesCode: species.ebirdSpeciesCode ?? species.scientificName
            )
        }
    }
    
    func predictBirds(for input: PredictionInputData, inputIndex: Int) async -> [FinalPredictionResult] {
        guard let lat = input.latitude,
              let lon = input.longitude else {
            return []
        }

        // 1. Sync this location to Supabase 'hotspots_geo' so the R script can see it
        // and so we can fetch existing scientific predictions if available.
        Task {
            do {
                let config = try SupabaseConfig.load()
                let body: [String: Any] = [
                    "ebird_hotspot_id": "USER_\(lat)_\(lon)", // Tagged as user-selected
                    "name": input.locationName ?? "User Selected Spot",
                    "locality": input.locationDetail ?? "Manual selection",
                    "location": "SRID=4326;POINT(\(lon) \(lat))"
                ]
                
                // Use the anonymous key for simple upsert
                var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
                components?.path = "/rest/v1/hotspots_geo"
                
                guard let url = components?.url else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
                request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                
                let _ = try await URLSession.shared.data(for: request)
            } catch {
            }
        }

        // 2. Fetch Scientific Predictions from the Supabase/R script Cache
        do {
            let response = try await SkyTrailsAPIService.shared.fetchPredictions(lat: lat, lng: lon)
            let results = (response.card?.species ?? []).map { species in
                let bird = watchlistManager.findBird(byName: species.commonName)
                
                let rawImage = species.imageName
                let cleanImage = (rawImage == nil || 
                                  rawImage == "placeholder_bird" || 
                                  rawImage == "placeholder_image" || 
                                  rawImage?.isEmpty == true) ? nil : rawImage

                let remoteImage = cleanImage ?? bird?.imageUrl ?? bird?.staticImageName

                return FinalPredictionResult(
                    birdName: species.commonName,
                    imageName: remoteImage ?? "placeholder_image",
                    likelySpot: input.locationName ?? "Nearby",
                    matchedInputIndex: inputIndex,
                    matchedLocation: (lat: lat, lon: lon),
                    spottingProbability: species.likelihood,
                    weekNumber: species.weekNumber,
                    residencyStatus: species.residencyStatus.rawValue,
                    ebirdSpeciesCode: species.ebirdSpeciesCode
                )
            }
            if !results.isEmpty { return results }
        } catch {
        }

        // Fallback to local live predictions if cache is empty
        return await getLivePredictions(for: lat, lon: lon, radiusKm: Double(input.areaValue))
            .map { result in
                FinalPredictionResult(
                    birdName: result.birdName,
                    imageName: result.imageName,
                    likelySpot: result.likelySpot,
                    matchedInputIndex: inputIndex,
                    matchedLocation: result.matchedLocation,
                    spottingProbability: result.spottingProbability,
                    weekNumber: result.weekNumber,
                    residencyStatus: result.residencyStatus,
                    ebirdSpeciesCode: result.ebirdSpeciesCode
                )
            }
    }

    func getRelevantSightings(for input: BirdDateInput) -> [RelevantSighting] {
        guard let birdId = UUID(uuidString: input.species.id) else { return [] }

        let birdDescriptor = FetchDescriptor<Bird>(
            predicate: #Predicate { bird in
                bird.bird_id == birdId
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

private struct RecommendationCacheRecord: Codable {
    let fetchLat: Double
    let fetchLng: Double
    let fetchedAt: Date
    let response: NearbyHotspotEdgeResponse
}

private final class RecommendationCacheStore {
    private let defaults = UserDefaults.standard
    private let key = "home_recommendation_edge_cache_v1"
    private let minRefreshDistanceMeters: CLLocationDistance = 5_000
    private let maxCacheAge: TimeInterval = 60 * 60 * 6

    func load() -> RecommendationCacheRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RecommendationCacheRecord.self, from: data)
    }

    func save(response: NearbyHotspotEdgeResponse, fetchLocation: CLLocationCoordinate2D) {
        let record = RecommendationCacheRecord(
            fetchLat: fetchLocation.latitude,
            fetchLng: fetchLocation.longitude,
            fetchedAt: Date(),
            response: response
        )
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    func shouldRefresh(
        cachedRecord: RecommendationCacheRecord,
        currentLocation: CLLocationCoordinate2D,
        distanceService: LocationServiceProtocol
    ) -> Bool {
        if Date().timeIntervalSince(cachedRecord.fetchedAt) > maxCacheAge {
            return true
        }
        let cachedLocation = CLLocationCoordinate2D(
            latitude: cachedRecord.fetchLat,
            longitude: cachedRecord.fetchLng
        )
        let movedDistance = distanceService.distance(from: currentLocation, to: cachedLocation)
        return movedDistance >= minRefreshDistanceMeters
    }
}

@MainActor
final class HotspotManager {
    private let modelContext: ModelContext
    private let logger: LoggingServiceProtocol
    private let birdsCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.countLimit = 100
        cache.totalCostLimit = 50_000_000
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
                birdWeekMap[bird.bird_id, default: []].formUnion(matchingWeeks)
                birdMap[bird.bird_id] = bird
            }
        }

        return birdMap.values.map { bird in
            (bird: bird, weeks: Array(birdWeekMap[bird.bird_id] ?? []).sorted())
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
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.startWeek <= week && session.endWeek >= week
            }
        )
        do {
            let sessions = try modelContext.fetch(descriptor)
            return sessions
        } catch {
            logger.log(error: error, context: "MigrationManager.getActiveMigrations")
            return []
        }
    }
    
    func getTrajectory(for session: MigrationSession, duringWeek week: Int) -> MigrationTrajectoryResult? {
        guard let allPaths = session.trajectoryPaths else {
            return nil
        }
        
        let currentPaths = allPaths.filter { $0.week == week }
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

    func getSessions(for bird: Bird) -> [MigrationSession] {
        let birdId = bird.bird_id
        let descriptor = FetchDescriptor<MigrationSession>(
            predicate: #Predicate { session in
                session.bird?.bird_id == birdId
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
