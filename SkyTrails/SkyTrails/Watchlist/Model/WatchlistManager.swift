
import Foundation
import SwiftData
import CoreLocation
import UIKit

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

@MainActor
final class WatchlistManager: WatchlistRepository {
    
    static let shared = WatchlistManager()
    static let didAdoptPendingWatchlistsNotification = Notification.Name("WatchlistManagerDidAdoptPendingWatchlists")
    
    private let container: ModelContainer
    internal let context: ModelContext
    
    private let persistence: WatchlistPersistenceService
    private let query: WatchlistQueryService
    private let rules: WatchlistRuleService
    private let photos: WatchlistPhotoService
    private let sorting: WatchlistSortingService
    private let ruleAssembly: WatchlistRuleAssemblyService
    private lazy var filtering: WatchlistFilteringService = WatchlistFilteringService(query: self, sorting: sorting)
    private lazy var orchestration: WatchlistEntryOrchestrationService = WatchlistEntryOrchestrationService(mutator: self)
    private let presentation: WatchlistPresentationService
    private let bootstrap: WatchlistBootstrapService
    
    private var isDataLoaded = false
    private var loadCompletionHandlers: [(Bool) -> Void] = []
    static let didLoadDataNotification = Notification.Name("WatchlistManagerDidLoadData")
    
    private init() {
        let schema = Schema([
            Watchlist.self,
            WatchlistEntry.self,
            WatchlistRule.self,
            WatchlistShare.self,
            ObservedBirdPhoto.self,
            Bird.self,
            BirdFieldMarkVariantLink.self,
            BirdShape.self,
            BirdFieldMark.self,
            FieldMarkVariant.self,
            IdentificationSession.self,
            IdentificationSessionFieldMark.self,
            IdentificationResult.self,
            IdentificationCandidate.self,
            Hotspot.self,
            HotspotSpeciesPresence.self,
            MigrationSession.self,
            TrajectoryPath.self,
            MigrationDataPayload.self,
            CommunityObservation.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            let fileManager = FileManager.default
            if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
               !fileManager.fileExists(atPath: supportDir.path) {
                try fileManager.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
            }

            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            WatchlistLog.error("Failed to init ModelContainer, resetting store", error: error)
            Self.resetDefaultSwiftDataStoreFiles()
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                WatchlistLog.error("Failed to init ModelContainer after reset", error: error)
                fatalError("Failed to init SwiftData after reset: \(error)")
            }
        }

        context = container.mainContext
        persistence = WatchlistPersistenceService(context: context)
        query = WatchlistQueryService(context: context, persistence: persistence)
        rules = WatchlistRuleService(context: context, persistence: persistence)
        photos = WatchlistPhotoService(context: context, persistence: persistence)
        sorting = WatchlistSortingService()
        ruleAssembly = WatchlistRuleAssemblyService()
        bootstrap = WatchlistBootstrapService(context: context)
        
        // Initialize presentation service first (doesn't depend on self)
        presentation = WatchlistPresentationService(query: query, persistence: persistence, photoService: photos)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoUploadNotification(_:)),
            name: NSNotification.Name("DidUploadPhoto"),
            object: nil
        )
        isDataLoaded = true
        DispatchQueue.main.async { [weak self] in
            self?.notifyDataLoaded(success: true)
        }
    }

    private static func resetDefaultSwiftDataStoreFiles() {
        let fileManager = FileManager.default
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
              let fileURLs = try? fileManager.contentsOfDirectory(
                at: supportDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else { return }

       
        let candidates = fileURLs.filter { url in
            let name = url.lastPathComponent
            return name == "default.store" || name.hasPrefix("default.store-")
        }

        for url in candidates {
            try? fileManager.removeItem(at: url)
        }
    }

    @MainActor
    func clearUserDataOnLogout() async {
        await bootstrap.clearUserDataOnLogout(photos: photos)
    }

    @objc
    private func handlePhotoUploadNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let id = info["id"] as? UUID,
              let storageUrl = info["storageUrl"] as? String
        else { return }

        let descriptor = FetchDescriptor<ObservedBirdPhoto>(
            predicate: #Predicate { $0.id == id }
        )

        if let photo = try? context.fetch(descriptor).first {
            photo.storageUrl = storageUrl
            photo.syncStatus = .synced
            photo.lastSyncedAt = Date()
            try? context.save()
        }
    }
    
    @MainActor
    func seedIfNeeded() {
        bootstrap.seedIfNeeded()
    }
    @MainActor
    func performGlobalSeeding() async {
        await bootstrap.performGlobalSeeding()
    }
    
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
            WatchlistLog.error("Failed to bind current user ownership", error: error)
        }
    }
    
    func deleteWatchlist(id: UUID) async throws {
        try persistence.deleteWatchlist(id: id)
    }
    
    func clearWatchlist(id: UUID) throws {
        try persistence.clearWatchlist(id: id)
    }
    
    func ensureMyWatchlistExists() async throws -> UUID {
        return WatchlistConstants.myWatchlistID
    }
    
    func getPersonalWatchlists() -> [Watchlist] {
        return (try? persistence.fetchWatchlists(type: .custom)) ?? []
    }
    
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

    func notifyDataDidChange() {
        NotificationCenter.default.post(
            name: WatchlistManager.didLoadDataNotification,
            object: self,
            userInfo: ["success": true]
        )
    }

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
    ) throws -> UUID {
        let watchlist = try persistence.createWatchlist(
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate,
            type: type
        )
        return watchlist.watchlist_id
    }
    
    func updateWatchlist(
        id: UUID,
        title: String,
        location: String?,
        locationDisplayName: String?,
        startDate: Date?,
        endDate: Date?
    ) throws {
        try persistence.updateWatchlist(
            id: id,
            title: title,
            location: location,
            locationDisplayName: locationDisplayName,
            startDate: startDate,
            endDate: endDate
        )
    }
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) throws -> [WatchlistEntry] {
        if watchlistID == WatchlistConstants.myWatchlistID {
            let allLists = try persistence.fetchWatchlists()
            return allLists.flatMap { watchlist in
                (watchlist.entries ?? []).filter { entry in
                    entry.syncStatus != .pendingDelete &&
                    (status == nil || entry.status == status)
                }
            }.sorted { $0.addedDate < $1.addedDate }
        }
        
        return try persistence.fetchEntries(watchlistID: watchlistID, status: status)
    }
    
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) throws {
        let targetWatchlistId = try resolveTargetWatchlistId(watchlistId)
        
        let status: WatchlistEntryStatus = asObserved ? .observed : .to_observe
        _ = try persistence.addBirdsToWatchlist(watchlistID: targetWatchlistId, birds: birds, status: status)
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
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func updateEntryDates(
        entryId: UUID,
        startDate: Date?,
        endDate: Date?
    ) throws {
        try persistence.updateEntry(
            id: entryId,
            notes: nil,
            observationDate: nil,
            lat: nil,
            lon: nil,
            locationDisplayName: nil,
            toObserveStartDate: startDate,
            toObserveEndDate: endDate
        )
    }
    
    func deleteEntry(entryId: UUID) throws {
        let watchlist = (try? persistence.fetchEntry(id: entryId))?.watchlist
        try persistence.deleteEntry(id: entryId)
        if let watchlist = watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func toggleObservationStatus(entryId: UUID) throws {
        try persistence.toggleEntryStatus(id: entryId)
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    func updateEntryNotifyUpcoming(entryId: UUID, notify: Bool) throws {
        try persistence.updateEntryNotifyUpcoming(id: entryId, notify: notify)
    }
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
        return (try? persistence.createBird(commonName: name)) ?? Bird(bird_id: UUID(),
            commonName: name,
            scientificName: "Unknown",
            staticImageName: "photo"
        )
    }
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
    func findEntry(birdId: UUID, watchlistId: UUID) throws -> WatchlistEntry? {
        let targetId = try resolveTargetWatchlistId(watchlistId)
        
        guard let watchlist = try persistence.fetchWatchlist(id: targetId) else { return nil }
        return watchlist.entries?.first(where: { $0.bird?.bird_id == birdId })
    }
    
    func attachPhoto(entryId: UUID, imageName: String) throws {
        _ = try photos.attachExistingPhoto(to: entryId, imagePath: imageName)
        if let entry = try? persistence.fetchEntry(id: entryId), let watchlist = entry.watchlist {
            refreshCoverImage(for: watchlist)
        }
    }
    
    private func refreshCoverImage(for watchlist: Watchlist) {
        Task {
            watchlist.updateCoverImage()
            try? context.save()
        }
    }
    
    // MARK: - Private Helpers
    
    /// Resolves a target watchlist ID, creating a fallback "My Watchlist" if needed.
    /// This centralizes the virtual-to-actual watchlist resolution logic.
    private func resolveTargetWatchlistId(_ watchlistId: UUID) throws -> UUID {
        guard watchlistId == WatchlistConstants.myWatchlistID else {
            return watchlistId
        }
        
        let customLists = try fetchWatchlists(type: .custom)
        if let existing = customLists.first(where: { $0.title == "My Watchlist" }) {
            return existing.watchlist_id
        } else if let first = customLists.first {
            return first.watchlist_id
        } else {
            _ = try addWatchlist(
                title: "My Watchlist",
                location: "General",
                startDate: Date(),
                endDate: Date().addingTimeInterval(31536000)
            )
            if let newWl = try fetchWatchlists(type: .custom).first(where: { $0.title == "My Watchlist" }) {
                return newWl.watchlist_id
            } else {
                throw WatchlistError.persistenceFailed(underlying: NSError(domain: "WatchlistManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create fallback watchlist"]))
            }
        }
    }
    func applyRules(to watchlistId: UUID) async throws {
        try await rules.applyRules(to: watchlistId)
    }
    
    func addRule(
        to watchlistId: UUID,
        type: WatchlistRuleType,
        parameters: RuleParameters,
        priority: Int = 0
    ) throws {
        try rules.validateRule(type: type, parameters: parameters)
        _ = try persistence.createRule(
            watchlistID: watchlistId,
            type: type,
            parameters: parameters,
            priority: priority
        )
    }
    
    func upsertRule(
        watchlistId: UUID,
        type: WatchlistRuleType,
        parameters: RuleParameters?,
        isActive: Bool = true,
        priority: Int = 0
    ) throws {
        if let parameters {
            try rules.validateRule(type: type, parameters: parameters)
            try persistence.upsertRule(
                watchlistID: watchlistId,
                type: type,
                parameters: parameters,
                isActive: isActive,
                priority: priority
            )
        } else {
            try persistence.deleteRule(watchlistID: watchlistId, type: type)
        }
    }
    
    func toggleRule(ruleId: UUID) throws {
        try persistence.toggleRule(id: ruleId)
    }
    
    func deleteRule(ruleId: UUID) throws {
        try persistence.deleteRule(id: ruleId)
    }
    func addBirdWithRuleMatching(
        bird: Bird,
        location: CLLocationCoordinate2D?,
        observationDate: Date?,
        notes: String?,
        asObserved: Bool
    ) throws -> [UUID] {
        let allWatchlists = try persistence.fetchWatchlists(type: .custom)
        var matchedWatchlistIds: [UUID] = []
        
        for watchlist in allWatchlists {
            let activeRules = (watchlist.rules ?? []).filter { $0.is_active && $0.deleted_at == nil }
            var isMatch = false

            for rule in activeRules {
                guard let ruleParams = RuleParameters.from(rule: rule) else { continue }
                
                switch ruleParams {
                case .speciesFamily(let params):
                    if bird.shape_id == params.shapeId {
                        isMatch = true
                    }
                    
                case .location(let params):
                    guard let birdLocation = location else { continue }
                    let watchlistLocation = CLLocation(latitude: params.lat, longitude: params.lon)
                    let birdCLLocation = CLLocation(latitude: birdLocation.latitude, longitude: birdLocation.longitude)
                    let distance = watchlistLocation.distance(from: birdCLLocation) / 1000.0
                    if distance <= params.radiusKm {
                        isMatch = true
                    }
                    
                case .dateRange(let params):
                    guard let birdDate = observationDate else { continue }
                    if birdDate >= params.startDate && birdDate <= params.endDate {
                        isMatch = true
                    }
                    
                case .migration(let params):
                    if bird.migration_strategy == params.patternKey {
                        isMatch = true
                    }
                }
                
                if isMatch {
                    break
                }
            }
            if isMatch {
                let status: WatchlistEntryStatus = asObserved ? .observed : .to_observe
                _ = try persistence.addBirdsToWatchlist(watchlistID: watchlist.watchlist_id, birds: [bird], status: status)
                refreshCoverImage(for: watchlist)
                if let newEntry = try? findEntry(birdId: bird.bird_id, watchlistId: watchlist.watchlist_id) {
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
                
                matchedWatchlistIds.append(watchlist.watchlist_id)
            }
        }
        
        if matchedWatchlistIds.isEmpty {
            throw WatchlistError.noMatchingWatchlists
        }
        return matchedWatchlistIds
    }
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
    
    func fetchBird(bird_id: UUID) throws -> Bird? {
        return try persistence.fetchBird(bird_id: bird_id)
    }
    
    func fetchAll<T: PersistentModel>(_ type: T.Type, descriptor: FetchDescriptor<T>? = nil) throws -> [T] {
        let fetchDescriptor = descriptor ?? FetchDescriptor<T>()
        return try context.fetch(fetchDescriptor)
    }
    
    func fetchOne<T: PersistentModel>(_ type: T.Type, descriptor: FetchDescriptor<T>) throws -> T? {
        return try context.fetch(descriptor).first
    }
    
    @available(*, deprecated, message: "Use LocationService.shared.reverseGeocode() instead")
    func lat_lon_to_Name(lat: Double, lon: Double) async -> String? {
        return await LocationService.shared.reverseGeocode(lat: lat, lon: lon)
    }
    
    @available(*, deprecated, message: "Direct context save is discouraged. Use service methods.")
    func saveContext() {
        try? context.save()
    }
    
    func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
        return query.buildMyWatchlistDTO(from: allLists)
    }
    
    func toDTO(_ model: Watchlist) -> WatchlistSummaryDTO {
        return model.toSummary()
    }
    
    // MARK: - Service Accessors
    
    /// Public accessor for the sorting service
    var sortingService: WatchlistSortingService {
        return sorting
    }
    
    /// Public accessor for the rule assembly service
    var ruleAssemblyService: WatchlistRuleAssemblyService {
        return ruleAssembly
    }
    
    /// Public accessor for the filtering service
    var filteringService: WatchlistFilteringService {
        return filtering
    }
    
    /// Public accessor for the orchestration service
    var orchestrationService: WatchlistEntryOrchestrationService {
        return orchestration
    }
    
    /// Public accessor for the presentation service
    var presentationService: WatchlistPresentationService {
        return presentation
    }
    
    // MARK: - ViewModel Creation (Delegated to PresentationService)
    
    /// Loads a complete ViewModel for MyWatchlist cell with pre-loaded images
    func loadMyWatchlistViewModel() async throws -> WatchlistCellViewModel {
        return try await presentation.loadMyWatchlistViewModel(fetchWatchlists: { try self.fetchWatchlists() })
    }
    
    /// Loads ViewModels for custom watchlist cells with pre-loaded cover images
    func loadCustomWatchlistViewModels(from dtos: [WatchlistSummaryDTO]) async -> [CustomWatchlistCellViewModel] {
        return await presentation.loadCustomWatchlistViewModels(from: dtos)
    }
    
    /// Loads ViewModels for bird entry cells with pre-loaded images
    func loadBirdEntryViewModels(from entries: [WatchlistEntry], shouldShowAvatars: Bool) async -> [BirdEntryCellViewModel] {
        return await presentation.loadBirdEntryViewModels(from: entries, shouldShowAvatars: shouldShowAvatars)
    }
    
    // MARK: - Convenience Image Loading (Delegated to PresentationService)
    
    func loadImage(path: String?) async -> UIImage? {
        return await presentation.loadImage(path: path)
    }
    
    func loadImageForEntry(_ entry: WatchlistEntry) async -> UIImage {
        return await presentation.loadImageForEntry(entry)
    }
}
