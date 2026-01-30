	//
//  WatchlistManager.swift
//  SkyTrails
//
//  Created by SDC-USER on 15/12/25.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
final class WatchlistManager {
    
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
				// Build schema from the model types
			let schema = Schema([
				Watchlist.self,
				WatchlistEntry.self,
				WatchlistRule.self,
				WatchlistShare.self,
				WatchlistImage.self,
				ObservedBirdPhoto.self,
				Bird.self     // ensure `@Model final class Bird { ... }` exists
			])
			
				// Create a configuration describing where/how to store the schema.
				// Do NOT redundantly pass `schema:` here — pass only persistence options.
			let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
			
				// Create the container for the schema with the configuration.
				// This matches the examples in the SwiftData docs / guides.
			container = try ModelContainer(for: schema, configurations: [modelConfiguration])
			context = container.mainContext
		} catch {
			fatalError("Failed to initialize SwiftData container: \(error)")
		}
		
		loadData()
	}


    // MARK: - Data Loading
    
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
    
    private func loadData() {
        // Check if data exists by counting Watchlists
        let count = (try? context.fetchCount(FetchDescriptor<Watchlist>())) ?? 0
        
        if count == 0 {
            print("No SwiftData records found. Attempting to seed from bundle...")
            seedInitialData()
        }
        
        // We verify success by checking if any watchlists exist now
        let hasData = (try? context.fetchCount(FetchDescriptor<Watchlist>())) ?? 0 > 0
        notifyDataLoaded(success: hasData)
    }
    
    // MARK: - Queries (The Source of Truth)
    
    func fetchWatchlists(type: WatchlistType? = nil) -> [Watchlist] {
        var descriptor = FetchDescriptor<Watchlist>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        if let type = type {
            // predicate support for enums in SwiftData can be tricky, but basic equality usually works
            descriptor.predicate = #Predicate { $0.type == type }
        }
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus? = nil) -> [WatchlistEntry] {
        // Fetch via parent relationship to avoid optional chaining predicate issues
        guard let watchlist = getWatchlist(by: watchlistID) else { return [] }
        var entries = watchlist.entries ?? []
        
        if let status = status {
            entries = entries.filter { $0.status == status }
        }
        
        return entries.sorted { $0.addedDate < $1.addedDate }
    }
    
    func fetchGlobalObservedCount() -> Int {
        // Fetch all entries and filter in memory to avoid predicate enum issues
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
        let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
    
    // MARK: - Seeding
    
    private func seedInitialData() {
        // Seed Custom Watchlists
        if let url = Bundle.main.url(forResource: "watchlists", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do {
                let dtos = try JSONDecoder().decode([JSONWatchlistDTO].self, from: data)
                for dto in dtos { createWatchlistFromDTO(dto, type: .custom) }
                print("Seeded \(dtos.count) custom watchlists.")
            } catch {
                print("Failed to decode watchlists.json: \(error)")
            }
        }
        
        // Seed Shared Watchlists
        if let url = Bundle.main.url(forResource: "sharedWatchlists", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do {
                let dtos = try JSONDecoder().decode([JSONSharedWatchlistDTO].self, from: data)
                for dto in dtos { createSharedWatchlistFromDTO(dto) }
                print("Seeded \(dtos.count) shared watchlists.")
            } catch {
                print("Failed to decode sharedWatchlists.json: \(error)")
            }
        }
        
        saveContext()
    }
    
    private func createWatchlistFromDTO(_ dto: JSONWatchlistDTO, type: WatchlistType) {
        let watchlist = Watchlist(
            id: dto.id,
            type: type,
            title: dto.title,
            location: dto.location,
            startDate: Date(timeIntervalSinceReferenceDate: dto.startDate),
            endDate: Date(timeIntervalSinceReferenceDate: dto.endDate)
        )
        if let mainImg = dto.mainImageName {
            context.insert(WatchlistImage(watchlist: watchlist, imagePath: mainImg))
        }
        context.insert(watchlist)
        processBirds(dto.observedBirds, for: watchlist, status: .observed)
        processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe)
    }
    
    private func createSharedWatchlistFromDTO(_ dto: JSONSharedWatchlistDTO) {
        let watchlist = Watchlist(
            id: dto.id,
            type: .shared,
            title: dto.title,
            location: dto.location
        )
        if !dto.mainImageName.isEmpty {
            context.insert(WatchlistImage(watchlist: watchlist, imagePath: dto.mainImageName))
        }
        context.insert(watchlist)
        processBirds(dto.observedBirds, for: watchlist, status: .observed)
        processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe)
    }
    
    private func processBirds(_ birdDTOs: [JSONBirdDTO], for watchlist: Watchlist, status: WatchlistEntryStatus) {
        for dto in birdDTOs {
            let bird = findOrCreateBird(from: dto)
            // No duplicate check needed for seeding, assuming clean data
            let entry = WatchlistEntry(
                watchlist: watchlist,
                bird: bird,
                status: status,
                notes: dto.notes,
                observedBy: dto.observedBy?.first
            )
            if status == .observed, let dateInterval = dto.date.first {
                entry.observationDate = Date(timeIntervalSinceReferenceDate: dateInterval)
            }
            context.insert(entry)
        }
    }
    
    private func findOrCreateBird(from dto: JSONBirdDTO) -> Bird {
        let name = dto.name
        let descriptor = FetchDescriptor<Bird>(predicate: #Predicate { $0.commonName == name })
        if let existing = try? context.fetch(descriptor).first { return existing }
        
        let rarityString = dto.rarity.first?.lowercased() ?? "common"
        let rarity: BirdRarityLevel = (rarityString == "rare") ? .rare : (rarityString == "very_rare" ? .very_rare : .common)
        
        let newBird = Bird(
            id: dto.id,
            commonName: dto.name,
            scientificName: dto.scientificName,
            staticImageName: dto.images.first ?? "placeholder",
            rarityLevel: rarity,
            validLocations: dto.location
        )
        context.insert(newBird)
        return newBird
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
    
    func deleteWatchlist(id: UUID) {
        if let wl = getWatchlist(by: id) {
            context.delete(wl)
            saveContext()
        }
    }
    
    func deleteEntry(entryId: UUID) {
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == entryId })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            saveContext()
        }
    }
    
    func updateEntry(entryId: UUID, notes: String?, observationDate: Date?, lat: Double? = nil, lon: Double? = nil) {
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == entryId })
        if let entry = try? context.fetch(descriptor).first {
            entry.notes = notes
            entry.observationDate = observationDate
            entry.lat = lat
            entry.lon = lon
            saveContext()
        }
    }
    
    /// Adds birds to a watchlist, strictly checking for duplicates via query first.
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
        guard let watchlist = getWatchlist(by: watchlistId) else { return }
        let existingEntries = watchlist.entries ?? []
        
        for bird in birds {
            // Check existence in memory via relationship to avoid complex predicates
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
        let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate { $0.id == entryId })
        if let entry = try? context.fetch(descriptor).first {
            entry.status = (entry.status == .observed) ? .to_observe : .observed
            entry.observationDate = (entry.status == .observed) ? Date() : nil
            saveContext()
        }
    }
    
    // MARK: - Special Cases
    
    func addRoseRingedParakeetToMyWatchlist() {
        // 1. Find "My Watchlist" via Query
        let wlDesc = FetchDescriptor<Watchlist>(predicate: #Predicate { $0.title == "My Watchlist" })
        var myWatchlist = try? context.fetch(wlDesc).first
        
        if myWatchlist == nil {
            let newWL = Watchlist(title: "My Watchlist", location: "Home", startDate: Date(), endDate: Date())
            newWL.type = .custom
            context.insert(newWL)
            myWatchlist = newWL
        }
        
        guard let targetWatchlist = myWatchlist else { return }
        
        // 2. Find Bird via Query
        let birdName = "Rose-ringed Parakeet"
        let birdDesc = FetchDescriptor<Bird>(predicate: #Predicate { $0.commonName == birdName })
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
        
        // 3. Add via Entry (Checking existence)
        addBirds([bird], to: targetWatchlist.id, asObserved: false)
        print("Rose-ringed Parakeet added to My Watchlist.")
    }
}

// MARK: - DTOs

private struct JSONWatchlistDTO: Codable {
    let id: UUID
    let title: String
    let location: String
    let startDate: TimeInterval
    let endDate: TimeInterval
    let observedBirds: [JSONBirdDTO]
    let toObserveBirds: [JSONBirdDTO]
    let mainImageName: String?
}

private struct JSONSharedWatchlistDTO: Codable {
    let id: UUID
    let title: String
    let location: String
    let dateRange: String
    let mainImageName: String
    let stats: JSONSharedStatsDTO
    let userImages: [String]
    let observedBirds: [JSONBirdDTO]
    let toObserveBirds: [JSONBirdDTO]
}

private struct JSONSharedStatsDTO: Codable {
    let greenValue: Int
    let blueValue: Int
}

private struct JSONBirdDTO: Codable {
    let id: UUID
    let name: String
    let scientificName: String
    let images: [String]
    let rarity: [String]
    let location: [String]
    let date: [TimeInterval]
    let observedBy: [String]?
    let notes: String?
}
