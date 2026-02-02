//
//  WatchlistManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 15/12/25.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - Repository Errors

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

// MARK: - Watchlist Manager

@MainActor
final class WatchlistManager: WatchlistRepository {
    
    static let shared = WatchlistManager()
    
    // MARK: - SwiftData
    
    private let container: ModelContainer
    private let context: ModelContext
    
    // MARK: - State Management
    
    private var isDataLoaded = false
    private var loadCompletionHandlers: [(Bool) -> Void] = []
    
    static let didLoadDataNotification = Notification.Name("WatchlistManagerDidLoadData")
    
    private init() {
        do {
            print("🚀 [WatchlistManager] Initializing...")
            
            // 1. Init Container
            let schema = Schema([
                Watchlist.self,
                WatchlistEntry.self,
                WatchlistRule.self,
                WatchlistShare.self,
                WatchlistImage.self,
                ObservedBirdPhoto.self,
                Bird.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            context = container.mainContext
            print("✅ [WatchlistManager] SwiftData container initialized")
            
            // TEMPORARY: Force database reset for testing
            print("🗑️  [WatchlistManager] Force clearing database for fresh seed...")
            let descriptor = FetchDescriptor<Watchlist>()
            if let existing = try? context.fetch(descriptor) {
                existing.forEach { context.delete($0) }
                try? context.save()
                print("✅ [WatchlistManager] Cleared \(existing.count) existing watchlists")
            }

            // 2. Perform Seeding
            do {
                try WatchlistSeeder.seed(context: context)
                print("✅ [WatchlistManager] Seeding completed successfully")
            } catch {
                print("❌ [WatchlistManager] Seeding failed: \(error)")
                print("⚠️  [WatchlistManager] Continuing with empty/existing database")
                // Don't fatal error - allow app to continue with empty DB
            }
            
            // 3. Notify Legacy Observers
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

    
    // MARK: - Repository Implementation
    
    func loadDashboardData() async throws -> (myWatchlist: WatchlistSummaryDTO?, custom: [WatchlistSummaryDTO], shared: [WatchlistSummaryDTO], globalStats: WatchlistStatsDTO) {
        
        // Fetch All
        let descriptor = FetchDescriptor<Watchlist>(sortBy: [SortDescriptor(\.created_at, order: .reverse)])
        let allLists = try context.fetch(descriptor)
        
        // Filter & Map (Business Logic here, not in VC)
        let myWatchlist = allLists.first(where: { $0.type == .my_watchlist }).map { toDTO($0) }
        let customLists = allLists.filter { $0.type == .custom }.map { toDTO($0) }
        let sharedLists = allLists.filter { $0.type == .shared }.map { toDTO($0) }
        
        // Calculate Global Stats
        let allEntries = allLists.flatMap { $0.entries ?? [] }
        let observedCount = allEntries.filter { $0.status == .observed }.count
        let rareCount = allEntries.filter { $0.status == .observed && ($0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare) }.count
        let totalCount = allEntries.count
        
        return (myWatchlist, customLists, sharedLists, WatchlistStatsDTO(observedCount: observedCount, totalCount: totalCount, rareCount: rareCount))
    }
    
    func deleteWatchlist(id: UUID) async throws {
        let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate<Watchlist> { watchlist in
            watchlist.id == id
        })
        guard let object = try context.fetch(descriptor).first else {
            throw RepositoryError.watchlistNotFound(id)
        }
        context.delete(object)
        try context.save()
    }
    
    func ensureMyWatchlistExists() async throws -> UUID {
        // Check for existing "My Watchlist" or type .my_watchlist
        // Note: We need to capture the enum value outside the predicate for Swift macro compatibility
        let myWatchlistType = WatchlistType.my_watchlist
        let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate<Watchlist> { watchlist in
            watchlist.type == myWatchlistType
        })
        if let existing = try? context.fetch(descriptor).first {
            return existing.id
        }
        
        // Fallback: Check by title if type migration failed
        let titleDescriptor = FetchDescriptor<Watchlist>(predicate: #Predicate<Watchlist> { watchlist in
            watchlist.title == "My Watchlist"
        })
        if let existing = try? context.fetch(titleDescriptor).first {
            existing.type = .my_watchlist // Auto-fix type
            try? context.save()
            return existing.id
        }
        
        // Create New
        let newWL = Watchlist(title: "My Watchlist", location: "Home", startDate: Date(), endDate: Date())
        newWL.type = .my_watchlist
        context.insert(newWL)
        
        // Add Legacy Seed Data (Rose-ringed Parakeet)
        addRoseRingedParakeetTo(watchlist: newWL)
        
        try context.save()
        return newWL.id
    }
    
    // MARK: - Internal Helpers
    
    private func addRoseRingedParakeetTo(watchlist: Watchlist) {
        let birdName = "Rose-ringed Parakeet"
        let birdDesc = FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
            bird.commonName == birdName
        })
        var targetBird = try? context.fetch(birdDesc).first
        
        if targetBird == nil {
            let newBird = Bird(
                commonName: birdName,
                scientificName: "Psittacula krameri",
                staticImageName: "rose_ringed_parakeet",
                rarityLevel: .common,
                validLocations: ["Pune, India"]
            )
            context.insert(newBird)
            targetBird = newBird
        }
        
        guard let bird = targetBird else { return }
        
        // Check if already exists to be safe
        let existingEntries = watchlist.entries ?? []
        if !existingEntries.contains(where: { $0.bird?.id == bird.id }) {
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: .to_observe
            )
            context.insert(entry)
        }
    }
    
    // MARK: - Mapper
    private func toDTO(_ model: Watchlist) -> WatchlistSummaryDTO {
        let entries = model.entries ?? []
        let observed = entries.filter { $0.status == .observed }.count
        
        // Calculate Stats
        let stats = WatchlistStatsDTO(
            observedCount: observed,
            totalCount: entries.count,
            rareCount: 0 // Simplification for list view
        )
        
        // Determine Image
        // Prioritize explicit images, then first bird image
        var imagePath: String? = model.images?.first?.imagePath
        if imagePath == nil {
             imagePath = model.entries?.first?.bird?.staticImageName
        }
        
        // Preview Images (up to 4)
        let previewImages = entries.compactMap { $0.bird?.staticImageName }.prefix(4).map { String($0) }
        
        // Subtitle logic
        let subtitle = model.location ?? "Unknown Location"
        
        // Date Text
        let dateText: String
        if let start = model.startDate, let end = model.endDate {
             let formatter = DateFormatter()
             formatter.dateFormat = "MMM"
             dateText = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
             dateText = ""
        }
        
        return WatchlistSummaryDTO(
            id: model.id,
            title: model.title ?? "Untitled",
            subtitle: subtitle,
            dateText: dateText,
            image: imagePath,
            previewImages: Array(previewImages),
            stats: stats,
            type: model.type ?? .custom
        )
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
    
    // MARK: - Legacy Queries
    
    func fetchWatchlists(type: WatchlistType? = nil) -> [Watchlist] {
        var descriptor = FetchDescriptor<Watchlist>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let type = type {
            descriptor.predicate = #Predicate<Watchlist> { watchlist in
                watchlist.type == type
            }
        }
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) -> [WatchlistEntry] {
        guard let watchlist = getWatchlist(by: watchlistID) else { return [] }
        var entries = watchlist.entries ?? []
        
        if let status = status {
            entries = entries.filter { $0.status == status }
        }
        
        return entries.sorted { $0.addedDate < $1.addedDate }
    }
    
    func fetchGlobalObservedCount() -> Int {
        let descriptor = FetchDescriptor<WatchlistEntry>()
        let allEntries = (try? context.fetch(descriptor)) ?? []
        return allEntries.filter { $0.status == .observed }.count
    }
    
    func getStats(for watchlistID: UUID) -> (observed: Int, total: Int) {
        guard let watchlist = getWatchlist(by: watchlistID), let entries = watchlist.entries else { return (0, 0) }
        
        let total = entries.count
        let observed = entries.filter { $0.status == .observed }.count
        return (observed, total)
    }
    
    func getWatchlist(by id: UUID) -> Watchlist? {
        let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate<Watchlist> { watchlist in
            watchlist.id == id
        })
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - CRUD Helpers
    
    private func saveContext() {
        try? context.save()
    }
    
    // MARK: - Operations
    
    func addWatchlist(title: String, location: String, startDate: Date, endDate: Date, type: WatchlistType = .custom) {
        let wl = Watchlist(title: title, location: location, startDate: startDate, endDate: endDate)
        wl.type = type
        context.insert(wl)
        saveContext()
    }
    
    func deleteEntry(entryId: UUID) {
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate<WatchlistEntry> { entry in
            entry.id == entryId
        })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            saveContext()
        }
    }
    
    func updateEntry(entryId: UUID, notes: String?, observationDate: Date?, lat: Double? = nil, lon: Double? = nil) {
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate<WatchlistEntry> { entry in
            entry.id == entryId
        })
        if let entry = try? context.fetch(descriptor).first {
            entry.notes = notes
            entry.observationDate = observationDate
            entry.lat = lat
            entry.lon = lon
            saveContext()
        }
    }
    
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
        guard let watchlist = getWatchlist(by: watchlistId) else { return }
        let existingEntries = watchlist.entries ?? []
        
        for bird in birds {
            if !existingEntries.contains(where: { $0.bird?.id == bird.id }) {
                let entry = WatchlistEntry(
                    watchlist: watchlist,
                    bird: bird,
                    status: asObserved ? .observed : .to_observe
                )
                if asObserved { entry.observationDate = Date() }
                context.insert(entry)
            }
        }
        saveContext()
    }
    
    func toggleObservationStatus(entryId: UUID) {
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate<WatchlistEntry> { entry in
            entry.id == entryId
        })
        if let entry = try? context.fetch(descriptor).first {
            entry.status = (entry.status == .observed) ? .to_observe : .observed
            entry.observationDate = (entry.status == .observed) ? Date() : nil
            saveContext()
        }
    }
}
