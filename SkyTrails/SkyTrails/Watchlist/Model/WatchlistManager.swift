//
//  WatchlistManager.swift
//  SkyTrails
//
//  Refactored: Service Coordinator Pattern
//  Delegates all business logic to focused services
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Legacy Repository Error (Deprecated, use WatchlistError)

@available(*, deprecated, message: "Use WatchlistError instead")
enum RepositoryError: Error, LocalizedError {
    case watchlistNotFound(UUID)
    case entryNotFound(UUID)
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .watchlistNotFound(let id):
            return "Watchlist not found: \(id)"
        case .entryNotFound(let id):
            return "Entry not found: \(id)"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Watchlist Manager (Service Coordinator)

@MainActor
final class WatchlistManager: WatchlistRepository {
    
    static let shared = WatchlistManager()
    static let didAdoptPendingWatchlistsNotification = Notification.Name("WatchlistManagerDidAdoptPendingWatchlists")
    
    // MARK: - SwiftData Container
    
    private let container: ModelContainer
    internal let context: ModelContext  // Shared internally within the model layer
    
    // MARK: - Services (Dependency Injection)
    
    private let persistence: WatchlistPersistenceService
    private let query: WatchlistQueryService
    private let rules: WatchlistRuleService
    private let photos: WatchlistPhotoService
    
    // MARK: - Legacy State Management
    
    private var isDataLoaded = false
    private var loadCompletionHandlers: [(Bool) -> Void] = []
    static let didLoadDataNotification = Notification.Name("WatchlistManagerDidLoadData")
    
    // MARK: - Initialization
    
    private init() {
        do {
            print("🚀 [WatchlistManager] Initializing...")
            
            // Ensure Application Support Directory Exists
            let fileManager = FileManager.default
            if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                if !fileManager.fileExists(atPath: supportDir.path) {
                    try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
                    print("✅ [WatchlistManager] Created Application Support directory")
                }
            }
            
            // Init SwiftData Container
            let schema = Schema([
                Watchlist.self,
                WatchlistEntry.self,
                WatchlistRule.self,
                WatchlistShare.self,
                ObservedBirdPhoto.self,
                Bird.self,
                // Identification models
                BirdShape.self,
                BirdFieldMark.self,
                FieldMarkVariant.self,
                IdentificationSession.self,
                IdentificationSessionFieldMark.self,
                IdentificationResult.self,
                IdentificationCandidate.self,
                // Integration models
                Hotspot.self,
                HotspotSpeciesPresence.self,
                MigrationSession.self,
                TrajectoryPath.self,
                MigrationDataPayload.self,
                CommunityObservation.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
            print("✅ [WatchlistManager] SwiftData container initialized")
            
            // Initialize Services
            persistence = WatchlistPersistenceService(context: context)
            query = WatchlistQueryService(context: context, persistence: persistence)
            rules = WatchlistRuleService(context: context, persistence: persistence)
            photos = WatchlistPhotoService(context: context, persistence: persistence)
            print("✅ [WatchlistManager] Services initialized")
            
            print("ℹ️ [WatchlistManager] Watchlist seeding deferred to AppDelegate")
            
            isDataLoaded = true
            
        } catch {
            print("💥 [WatchlistManager] FATAL: Failed to init SwiftData: \(error)")
            fatalError("Failed to init SwiftData: \(error)")
        }
        
        // Post-Init Notification for legacy support
        DispatchQueue.main.async { [weak self] in
            self?.notifyDataLoaded(success: true)
        }
    }
    
    @MainActor
    func seedIfNeeded() {
        let hasSeededKey = "kAppHasSeededData_v1"
        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else {
            print("ℹ️ [WatchlistManager] Database already seeded. Skipping watchlist seed.")
            return
        }
        
        print("🗑️ [WatchlistManager] First launch or reset: clearing watchlists...")
        let descriptor = FetchDescriptor<Watchlist>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        try? context.save()
        print("✅ [WatchlistManager] Cleared watchlists")
        
        do {
            try WatchlistSeeder.seed(context: context)
            UserDefaults.standard.set(true, forKey: hasSeededKey)
            print("✅ [WatchlistManager] Watchlist seeding completed successfully")
        } catch {
            print("❌ [WatchlistManager] Watchlist seeding failed: \(error)")
        }
    }

    /// Global seeding orchestrator called from AppDelegate
    @MainActor
    func performGlobalSeeding() async {
        print("🌱 [WatchlistManager] Starting sequential database seeding...")
        
        do {
            print("📚 [WatchlistManager] Step 1/3: Seeding Bird Database...")
            try BirdDatabaseSeeder.shared.seed(modelContext: context)
            print("✅ [WatchlistManager] Bird Database seeded successfully")
            
            print("🦆 [WatchlistManager] Step 2/3: Seeding WatchlistsIfNeeded...")
            seedIfNeeded()
            
            print("🏠 [WatchlistManager] Step 3/3: Seeding Home Data...")
            try await HomeDataSeeder.shared.seed(modelContext: context)
            print("✅ [WatchlistManager] Home Data seeded successfully")
            
            print("✅ [WatchlistManager] All seeding complete")
        } catch {
            print("❌ [WatchlistManager] CRITICAL: Global seeding failed: \(error)")
        }
    }
    
    // MARK: - Repository Protocol Implementation
    
    func loadDashboardData() async throws -> (
        myWatchlist: WatchlistSummaryDTO?,
        custom: [WatchlistSummaryDTO],
        shared: [WatchlistSummaryDTO],
        globalStats: WatchlistStatsDTO
    ) {
        _ = try persistence.bindWatchlistsToCurrentUser()
        return try await query.loadDashboardData()
    }

    func bindCurrentUserOwnership() async {
        do {
            let adoptedCount = try persistence.bindWatchlistsToCurrentUser()
            if adoptedCount > 0, let userID = UserSession.shared.currentUserID {
                NotificationCenter.default.post(
                    name: Self.didAdoptPendingWatchlistsNotification,
                    object: self,
                    userInfo: [
                        "adoptedCount": adoptedCount,
                        "userID": userID.uuidString
                    ]
                )
            }
        } catch {
            print("⚠️ [WatchlistManager] Failed to bind watchlist ownership: \(error)")
        }
    }
    
    func deleteWatchlist(id: UUID) async throws {
        try persistence.deleteWatchlist(id: id)
    }
    
    func ensureMyWatchlistExists() async throws -> UUID {
        // My Watchlist is now virtual, return special ID
        return WatchlistConstants.myWatchlistID
    }
    
    func getPersonalWatchlists() -> [Watchlist] {
        return (try? persistence.fetchWatchlists(type: .custom)) ?? []
    }
    
    // MARK: - Legacy Data Loading Support
    
    func onDataLoaded(_ handler: @escaping (Bool) -> Void) {
        if isDataLoaded {
            handler(true)
        } else {
            loadCompletionHandlers.append(handler)
        }
    }
    
    private func notifyDataLoaded(success: Bool) {
        isDataLoaded = true
        NotificationCenter.default.post(
            name: WatchlistManager.didLoadDataNotification,
            object: self,
            userInfo: ["success": success]
        )
        loadCompletionHandlers.forEach { $0(success) }
        loadCompletionHandlers.removeAll()
    }
    
    // MARK: - Public API (Delegates to Services)
    
    // CRUD Operations
    func fetchWatchlists(type: WatchlistType? = nil) throws -> [Watchlist] {
        return try persistence.fetchWatchlists(type: type)
    }
    
    func getWatchlist(by id: UUID) throws -> Watchlist? {
        return try persistence.fetchWatchlist(id: id)
    }
    
    func addWatchlist(
        title: String,
        location: String,
        startDate: Date,
        endDate: Date,
        type: WatchlistType = .custom,
        locationDisplayName: String? = nil
    ) throws {
        _ = try persistence.createWatchlist(
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate,
            type: type
        )
    }
    
    // Entry Operations
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) throws -> [WatchlistEntry] {
        // Handle virtual "My Watchlist" ID
        if watchlistID == WatchlistConstants.myWatchlistID {
            let identifier = WatchlistIdentifier.virtual
            let filter = WatchlistQueryFilter(status: status)
            let dtos = try query.fetchEntries(identifier: identifier, filter: filter)
            // Convert back to entities for legacy support (not ideal, but preserves compatibility)
            return dtos.compactMap { dto in
                try? persistence.fetchEntry(id: dto.id)
            }
        }
        
        return try persistence.fetchEntries(watchlistID: watchlistID, status: status)
    }
    
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) throws {
        print("🐦 [WatchlistManager] addBirds() delegating to service...")
        
        var targetWatchlistId = watchlistId
        let myWatchlistId = WatchlistConstants.myWatchlistID
        
        // Resolve virtual "My Watchlist" ID to real watchlist
        if watchlistId == myWatchlistId {
            print("⚠️ [WatchlistManager] Virtual 'My Watchlist' ID detected, resolving...")
            let customLists = try fetchWatchlists(type: .custom)
            if let existing = customLists.first(where: { $0.title == "My Watchlist" }) {
                targetWatchlistId = existing.id
            } else if let first = customLists.first {
                targetWatchlistId = first.id
            } else {
                // Create fallback watchlist
                try addWatchlist(
                    title: "My Watchlist",
                    location: "General",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(31536000)
                )
                if let newWl = try fetchWatchlists(type: .custom).first(where: { $0.title == "My Watchlist" }) {
                    targetWatchlistId = newWl.id
                } else {
                    print("❌ [WatchlistManager] CRITICAL: Failed to create fallback watchlist")
                    throw WatchlistError.persistenceFailed(underlying: NSError(domain: "WatchlistManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create fallback watchlist"]))
                }
            }
        }
        
        let status: WatchlistEntryStatus = asObserved ? .observed : .to_observe
        _ = try persistence.addBirdsToWatchlist(watchlistID: targetWatchlistId, birds: birds, status: status)
        
        // Refresh cover image
        if let watchlist = try? persistence.fetchWatchlist(id: targetWatchlistId) {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func updateEntry(
        entryId: UUID,
        notes: String?,
        observationDate: Date?,
        lat: Double? = nil,
        lon: Double? = nil,
        locationDisplayName: String? = nil
    ) throws {
        try persistence.updateEntry(
            id: entryId,
            notes: notes,
            observationDate: observationDate,
            lat: lat,
            lon: lon,
            locationDisplayName: locationDisplayName,
            toObserveStartDate: nil,
            toObserveEndDate: nil
        )
        
        // Refresh cover image if observation date changed
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func deleteEntry(entryId: UUID) throws {
        let watchlist = (try? persistence.fetchEntry(id: entryId))?.watchlist
        try persistence.deleteEntry(id: entryId)
        
        // Refresh cover image
        if let watchlist = watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func toggleObservationStatus(entryId: UUID) throws {
        try persistence.toggleEntryStatus(id: entryId)
        
        // Refresh cover image
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    // Bird Operations
    func fetchAllBirds() -> [Bird] {
        return (try? persistence.fetchAllBirds()) ?? []
    }
    
    func findBird(byName name: String) -> Bird? {
        return try? persistence.fetchBird(byCommonName: name)
    }
    
    func createBird(name: String) -> Bird {
        if let existing = try? persistence.fetchBird(byCommonName: name) {
            return existing
        }
        return (try? persistence.createBird(commonName: name)) ?? Bird(
            id: UUID(),
            commonName: name,
            scientificName: "Unknown",
            staticImageName: "photo",
            rarityLevel: .common,
            validLocations: []
        )
    }
    
    // Stats
    func getStats(for watchlistID: UUID) throws -> (observed: Int, total: Int) {
        let identifier: WatchlistIdentifier
        if watchlistID == WatchlistConstants.myWatchlistID {
            identifier = .virtual
        } else {
            identifier = .custom(watchlistID)
        }
        
        let stats = try query.getStats(for: identifier)
        return (stats.observedCount, stats.totalCount)
    }
    
    func fetchGlobalObservedCount() throws -> Int {
        return try query.getGlobalObservedCount()
    }
    
    // Photo Operations
    func findEntry(birdId: UUID, watchlistId: UUID) throws -> WatchlistEntry? {
        // Resolve virtual My Watchlist ID
        var targetId = watchlistId
        if watchlistId == WatchlistConstants.myWatchlistID {
            let customLists = try fetchWatchlists(type: .custom)
            if let existing = customLists.first(where: { $0.title == "My Watchlist" }) {
                targetId = existing.id
            } else if let first = customLists.first {
                targetId = first.id
            }
        }
        
        guard let watchlist = try persistence.fetchWatchlist(id: targetId) else { return nil }
        return watchlist.entries?.first(where: { $0.bird?.id == birdId })
    }
    
    func attachPhoto(entryId: UUID, imageName: String) throws {
        _ = try photos.attachExistingPhoto(to: entryId, imagePath: imageName)
        
        // Refresh cover image
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    // MARK: - Internal Helpers
    
    private func refreshCoverImage(for watchlist: Watchlist) {
        Task {
            watchlist.updateCoverImage()
            try? context.save()
        }
    }
    
    // Rule Operations
    func applyRules(to watchlistId: UUID) async throws {
        try await rules.applyRules(to: watchlistId)
    }
    
    func addRule(
        to watchlistId: UUID,
        type: WatchlistRuleType,
        parameters: Encodable,
        priority: Int = 0
    ) throws {
        // Convert Encodable to RuleParameters
        let encoder = JSONEncoder()
        let data = try encoder.encode(parameters)
        let jsonString = String(data: data, encoding: .utf8) ?? "{}"
        
        guard let ruleParams = RuleParameters.from(type: type, json: jsonString) else {
            throw WatchlistError.ruleValidationFailed("Invalid parameters")
        }
        
        try rules.validateRule(type: type, parameters: ruleParams)
        _ = try persistence.createRule(
            watchlistID: watchlistId,
            type: type,
            parameters: ruleParams,
            priority: priority
        )
    }
    
    func toggleRule(ruleId: UUID) throws {
        try persistence.toggleRule(id: ruleId)
    }
    
    func deleteRule(ruleId: UUID) throws {
        try persistence.deleteRule(id: ruleId)
    }
    
    // MARK: - Rule-Based Bird Matching
    
    /// Adds a bird to all watchlists that match the active rules
    /// - Parameters:
    ///   - bird: The bird to add
    ///   - location: Observation location (required for location rule matching)
    ///   - observationDate: Observation date (required for date rule matching)
    ///   - notes: Optional notes for the entry
    ///   - asObserved: Whether to mark as observed or to_observe
    /// - Returns: Array of watchlist IDs where the bird was added
    /// - Throws: WatchlistError.noMatchingWatchlists if no watchlists match
    func addBirdWithRuleMatching(
        bird: Bird,
        location: CLLocationCoordinate2D?,
        observationDate: Date?,
        notes: String?,
        asObserved: Bool
    ) throws -> [UUID] {
        print("🎯 [WatchlistManager] addBirdWithRuleMatching() called for: \(bird.commonName)")
        
        // Fetch all custom watchlists
        let allWatchlists = try persistence.fetchWatchlists(type: .custom)
        var matchedWatchlistIds: [UUID] = []
        
        for watchlist in allWatchlists {
            var isMatch = false
            
            // Check Species Rule
            if watchlist.speciesRuleEnabled, let shapeId = watchlist.speciesRuleShapeId {
                if bird.shape_id == shapeId || bird.shape_id == nil {
                    print("✅ Species rule MATCH for watchlist: \(watchlist.title ?? "Unnamed")")
                    isMatch = true
                }
            }
            
            // Check Location Rule
            if !isMatch && watchlist.locationRuleEnabled,
               let watchlistLat = watchlist.locationRuleLat,
               let watchlistLon = watchlist.locationRuleLon,
               let birdLocation = location {
                let watchlistLocation = CLLocation(latitude: watchlistLat, longitude: watchlistLon)
                let birdCLLocation = CLLocation(latitude: birdLocation.latitude, longitude: birdLocation.longitude)
                let distance = watchlistLocation.distance(from: birdCLLocation) / 1000.0 // Convert to km
                
                if distance <= watchlist.locationRuleRadiusKm {
                    print("✅ Location rule MATCH for watchlist: \(watchlist.title ?? "Unnamed") (distance: \(Int(distance))km)")
                    isMatch = true
                }
            }
            
            // Check Date Rule
            if !isMatch && watchlist.dateRuleEnabled,
               let startDate = watchlist.dateRuleStartDate,
               let endDate = watchlist.dateRuleEndDate,
               let birdDate = observationDate {
                if birdDate >= startDate && birdDate <= endDate {
                    print("✅ Date rule MATCH for watchlist: \(watchlist.title ?? "Unnamed")")
                    isMatch = true
                }
            }
            
            // If any rule matched, add bird to this watchlist
            if isMatch {
                let status: WatchlistEntryStatus = asObserved ? .observed : .to_observe
                _ = try persistence.addBirdsToWatchlist(watchlistID: watchlist.id, birds: [bird], status: status)
                
                // Refresh cover image
                refreshCoverImage(for: watchlist)
                
                // Update the entry with notes and location if provided
                if let newEntry = try? findEntry(birdId: bird.id, watchlistId: watchlist.id) {
                    try persistence.updateEntry(
                        id: newEntry.id,
                        notes: notes,
                        observationDate: asObserved ? observationDate : nil,
                        lat: location?.latitude,
                        lon: location?.longitude,
                        locationDisplayName: nil,
                        toObserveStartDate: asObserved ? nil : observationDate,
                        toObserveEndDate: asObserved ? nil : observationDate
                    )
                }
                
                matchedWatchlistIds.append(watchlist.id)
            }
        }
        
        if matchedWatchlistIds.isEmpty {
            print("❌ [WatchlistManager] No watchlists matched the rules")
            throw WatchlistError.noMatchingWatchlists
        }
        
        print("✅ [WatchlistManager] Bird added to \(matchedWatchlistIds.count) watchlist(s)")
        return matchedWatchlistIds
    }
    
    // Query Operations
    func getUpcomingBirds(
        userLocation: CLLocationCoordinate2D,
        currentWeek: Int,
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) async throws -> [UpcomingBirdResult] {
        return try await query.getUpcomingBirds(
            userLocation: userLocation,
            currentWeek: currentWeek,
            lookAheadWeeks: lookAheadWeeks,
            radiusInKm: radiusInKm
        )
    }
    
    func getUpcomingBirdsAtHome(
        lookAheadWeeks: Int = 4,
        radiusInKm: Double = 50.0
    ) async throws -> [UpcomingBirdResult] {
        guard let homeLocation = LocationPreferences.shared.homeLocation else {
            return []
        }
        let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
        return try await getUpcomingBirds(
            userLocation: homeLocation,
            currentWeek: currentWeek,
            lookAheadWeeks: lookAheadWeeks,
            radiusInKm: radiusInKm
        )
    }
    
    func getEntriesObservedNear(
        location: CLLocationCoordinate2D,
        radiusInKm: Double = 10.0,
        watchlistId: UUID? = nil
    ) throws -> [WatchlistEntry] {
        let identifier = watchlistId.map { WatchlistIdentifier.from(uuid: $0, type: nil) }
        let dtos = try query.getEntriesObservedNear(
            location: location,
            radiusInKm: radiusInKm,
            watchlistID: identifier
        )
        return dtos.compactMap { try? persistence.fetchEntry(id: $0.id) }
    }
    
    func getEntriesInDateRange(
        start: Date,
        end: Date,
        watchlistId: UUID? = nil
    ) throws -> [WatchlistEntry] {
        let identifier = watchlistId.map { WatchlistIdentifier.from(uuid: $0, type: nil) }
        let dtos = try query.getEntriesInDateRange(
            start: start,
            end: end,
            watchlistID: identifier
        )
        return dtos.compactMap { try? persistence.fetchEntry(id: $0.id) }
    }
    
    func getEntriesForThisWeek(watchlistId: UUID? = nil) throws -> [WatchlistEntry] {
        let identifier = watchlistId.map { WatchlistIdentifier.from(uuid: $0, type: nil) }
        let dtos = try query.getEntriesForThisWeek(watchlistID: identifier)
        return dtos.compactMap { try? persistence.fetchEntry(id: $0.id) }
    }
    
    // MARK: - Global Data Access (for HomeManager components)
    // Providing managed access to core entities without leaking context directly
    
    func fetchBird(id: UUID) throws -> Bird? {
        return try persistence.fetchBird(id: id)
    }
    
    func fetchAll<T: PersistentModel>(_ type: T.Type, descriptor: FetchDescriptor<T>? = nil) throws -> [T] {
        let fetchDescriptor = descriptor ?? FetchDescriptor<T>()
        return try context.fetch(fetchDescriptor)
    }
    
    func fetchOne<T: PersistentModel>(_ type: T.Type, descriptor: FetchDescriptor<T>) throws -> T? {
        return try context.fetch(descriptor).first
    }
    
    // MARK: - Deprecated Methods
    
    @available(*, deprecated, message: "Use LocationService.shared.reverseGeocode() instead")
    func lat_lon_to_Name(lat: Double, lon: Double) async -> String? {
        return await LocationService.shared.reverseGeocode(lat: lat, lon: lon)
    }
    
    @available(*, deprecated, message: "Direct context save is discouraged. Use service methods.")
    func saveContext() {
        try? context.save()
    }
    
    // MARK: - DTO Mapping (Legacy Support)
    
    func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
        return query.buildMyWatchlistDTO(from: allLists)
    }
    
    func toDTO(_ model: Watchlist) -> WatchlistSummaryDTO {
        return model.toSummary()
    }
}
