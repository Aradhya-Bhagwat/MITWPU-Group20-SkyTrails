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
	
		// MARK: - Public Properties
	
	private(set) var watchlists: [Watchlist] = []
	private(set) var sharedWatchlists: [SharedWatchlist] = []
	
		// MARK: - SwiftData
	
	private let container: ModelContainer
	private let context: ModelContext
	
		// MARK: - State Management
	
	private var isDataLoaded = false
	private var loadCompletionHandlers: [(Bool) -> Void] = []
	
	static let didLoadDataNotification = Notification.Name("WatchlistManagerDidLoadData")
	
	private init() {
		do {
				// Initialize SwiftData container
			let schema = Schema([
				Watchlist.self,
				SharedWatchlist.self,
				Bird.self
			])
			let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
			container = try ModelContainer(for: schema, configurations: [modelConfiguration])
			context = container.mainContext
		} catch {
			fatalError("Failed to initialize SwiftData container: \(error)")
		}
		
		loadData()
	}
	
		// MARK: - Data Loading & Migration
	
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
		fetchAll()
		
		if watchlists.isEmpty && sharedWatchlists.isEmpty {
			print("No SwiftData records found. Attempting to seed from bundle...")
			seedInitialData()
			fetchAll()
		}
		
		let hasData = !watchlists.isEmpty || !sharedWatchlists.isEmpty
		notifyDataLoaded(success: hasData)
	}
	
	private func fetchAll() {
		do {
			let watchlistDescriptor = FetchDescriptor<Watchlist>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
			watchlists = try context.fetch(watchlistDescriptor)
			
			let sharedWatchlistDescriptor = FetchDescriptor<SharedWatchlist>(sortBy: [SortDescriptor(\.title)])
			sharedWatchlists = try context.fetch(sharedWatchlistDescriptor)
		} catch {
			print("Failed to fetch data: \(error)")
		}
	}
	
	private func seedInitialData() {
			// Seed Custom Watchlists
		if let url = Bundle.main.url(forResource: "watchlists", withExtension: "json"),
		   let data = try? Data(contentsOf: url) {
			do {
					// Decode into temporary DTOs matching the JSON structure
				let jsonWatchlists = try JSONDecoder().decode([JSONWatchlistDTO].self, from: data)
				
				for jsonDTO in jsonWatchlists {
					let watchlist = mapJSONToWatchlist(jsonDTO)
					context.insert(watchlist)
				}
				print("Seeded \(jsonWatchlists.count) watchlists from bundle.")
			} catch {
				print("Failed to decode watchlists json: \(error)")
			}
		}
		
			// Seed Shared Watchlists
		if let url = Bundle.main.url(forResource: "sharedWatchlists", withExtension: "json"),
		   let data = try? Data(contentsOf: url) {
			do {
				let jsonSharedWatchlists = try JSONDecoder().decode([JSONSharedWatchlistDTO].self, from: data)
				
				for jsonDTO in jsonSharedWatchlists {
					let sharedWL = mapJSONToSharedWatchlist(jsonDTO)
					context.insert(sharedWL)
				}
				print("Seeded \(jsonSharedWatchlists.count) shared watchlists from bundle.")
			} catch {
				print("Failed to decode shared watchlists json: \(error)")
			}
		}
		
		saveContext()
	}
	
		// MARK: - Mappers
	
	private func mapJSONToWatchlist(_ dto: JSONWatchlistDTO) -> Watchlist {
		var birds: [Bird] = []
		
			// Map Observed Birds from JSON
		for b in dto.observedBirds {
			let bird = mapJSONToBird(b, status: .observed)
			birds.append(bird)
		}
		
			// Map To-Observe Birds from JSON
		for b in dto.toObserveBirds {
			let bird = mapJSONToBird(b, status: .toObserve)
			birds.append(bird)
		}
		
		return Watchlist(
			id: dto.id,
			title: dto.title,
			location: dto.location,
			startDate: Date(timeIntervalSinceReferenceDate: dto.startDate),
			endDate: Date(timeIntervalSinceReferenceDate: dto.endDate),
			birds: birds
		)
	}
	
	private func mapJSONToSharedWatchlist(_ dto: JSONSharedWatchlistDTO) -> SharedWatchlist {
		var birds: [Bird] = []
		
		for b in dto.observedBirds {
			let bird = mapJSONToBird(b, status: .observed)
			birds.append(bird)
		}
		
		for b in dto.toObserveBirds {
			let bird = mapJSONToBird(b, status: .toObserve)
			birds.append(bird)
		}
		
		let stats = SharedWatchlistStats(
			greenValue: dto.stats.greenValue,
			blueValue: dto.stats.blueValue
		)
		
		return SharedWatchlist(
			id: dto.id,
			title: dto.title,
			location: dto.location,
			dateRange: dto.dateRange,
			mainImageName: dto.mainImageName,
			stats: stats,
			userImages: dto.userImages,
			birds: birds
		)
	}
	
	private func mapJSONToBird(_ dto: JSONBirdDTO, status: Bird.ObservationStatus) -> Bird {
			// Map string array of rarities to BirdRarity Enum
		let rarityEnums: [Bird.BirdRarity] = dto.rarity.compactMap {
			Bird.BirdRarity(rawValue: $0.lowercased())
		}
		
			// Map time intervals to Date
		let dates = dto.date.map { Date(timeIntervalSinceReferenceDate: $0) }
		
			// Map observedBy array to single string
		let observedByStr = dto.observedBy?.joined(separator: ", ")
		
		return Bird(
			id: dto.id,
			name: dto.name,
			scientificName: dto.scientificName,
			staticImageName: dto.images.first ?? "placeholder_image",
			lat: nil,
			lon: nil,
			validLocations: dto.location,
			validMonths: nil,
			observationDates: dates,
			IdentificationShape: nil,
			shapeId: nil,
			sizeCategory: nil,
			rarity: rarityEnums,
			fieldMarks: nil,
			confidence: nil,
			scoreBreakdown: nil,
			userImages: nil, // JSON DTO doesn't map directly to userImages list in Bird model
			observedBy: observedByStr,
			notes: dto.notes,
			isUserCreated: false,
			observationStatus: status
		)
	}
	
		// MARK: - CRUD Helpers
	
	private func saveContext() {
		do {
			try context.save()
			fetchAll() // Refresh local arrays
		} catch {
			print("Failed to save context: \(error)")
		}
	}
	
		// MARK: - Public Accessors
	
	func getWatchlist(by id: UUID) -> Watchlist? {
		watchlists.first { $0.id == id }
	}
	
	func getSharedWatchlist(by id: UUID) -> SharedWatchlist? {
		sharedWatchlists.first { $0.id == id }
	}
	
		// MARK: - Calculated Stats
	
	var totalSpeciesCount: Int {
		watchlists.reduce(0) { $0 + $1.birds.count }
	}
	
	var totalObservedCount: Int {
		watchlists.reduce(0) { $0 + $1.observedCount }
	}
	
	var totalRareCount: Int {
		watchlists.reduce(0) { total, watchlist in
			let rareCount = watchlist.birds.filter { $0.rarity?.contains(.rare) ?? false }.count
			return total + rareCount
		}
	}
	
		// MARK: - Operations
	
	func addWatchlist(_ watchlist: Watchlist) {
		guard !watchlist.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		context.insert(watchlist)
		saveContext()
	}
	
	func addSharedWatchlist(_ watchlist: SharedWatchlist) {
		guard !watchlist.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		context.insert(watchlist)
		saveContext()
	}
	
	func deleteWatchlist(id: UUID) {
		if let watchlist = getWatchlist(by: id) {
			context.delete(watchlist)
			saveContext()
		}
	}
	
	func deleteSharedWatchlist(id: UUID) {
		if let watchlist = getSharedWatchlist(by: id) {
			context.delete(watchlist)
			saveContext()
		}
	}
	
	func updateWatchlist(id: UUID, title: String, location: String, startDate: Date, endDate: Date) {
		guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		
		if let watchlist = getWatchlist(by: id) {
			watchlist.title = title
			watchlist.location = location
			watchlist.startDate = startDate
			watchlist.endDate = endDate
			saveContext()
		}
	}
	
	func updateSharedWatchlist(id: UUID, title: String, location: String, dateRange: String) {
		guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
		
		if let watchlist = getSharedWatchlist(by: id) {
			watchlist.title = title
			watchlist.location = location
			watchlist.dateRange = dateRange
			saveContext()
		}
	}
	
	func updateSharedWatchlistUserImages(id: UUID, userImages: [String]) {
		if let watchlist = getSharedWatchlist(by: id) {
			watchlist.userImages = userImages
			saveContext()
		}
	}
	
		// MARK: - Bird Management
	
	func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
			// Identify target watchlist type
		if let watchlist = getWatchlist(by: watchlistId) {
			for bird in birds {
				bird.observationStatus = asObserved ? .observed : .toObserve
				bird.watchlist = watchlist
				context.insert(bird)
				watchlist.birds.append(bird)
			}
			saveContext()
		} else if let sharedWatchlist = getSharedWatchlist(by: watchlistId) {
			for bird in birds {
				bird.observationStatus = asObserved ? .observed : .toObserve
				bird.sharedWatchlist = sharedWatchlist
				context.insert(bird)
				sharedWatchlist.birds.append(bird)
			}
			saveContext()
		}
	}
	
	func deleteBird(_ bird: Bird, from watchlistId: UUID) {
		context.delete(bird)
		saveContext()
	}
	
	func saveObservation(bird: Bird, watchlistId: UUID) {
		bird.observationStatus = .observed
		saveContext()
	}
	
	func updateBird(_ bird: Bird, watchlistId: UUID) {
		saveContext()
	}
	
		// MARK: - Special Cases
	
	func addRoseRingedParakeetToMyWatchlist() {
		let targetWatchlist: Watchlist
		if let existing = watchlists.first(where: { $0.title == "My Watchlist" }) {
			targetWatchlist = existing
		} else {
			let newWL = Watchlist(
				title: "My Watchlist",
				location: "Home",
				startDate: Date(),
				endDate: Date()
			)
			context.insert(newWL)
			targetWatchlist = newWL
		}
		
		let roseRingedParakeet = Bird(
			id: UUID(),
			name: "Rose-ringed Parakeet",
			scientificName: "Psittacula krameri",
			staticImageName: "rose_ringed_parakeet",
			validLocations: ["Pune, India"],
			observationDates: [Date()],
			rarity: [.common],
			notes: "Added by user request.",
			observationStatus: .toObserve
		)
		
		roseRingedParakeet.watchlist = targetWatchlist
		targetWatchlist.birds.append(roseRingedParakeet)
		
		saveContext()
		print("Rose-ringed Parakeet added to My Watchlist.")
	}
}

// MARK: - Private JSON Data Transfer Objects (DTOs)
// These structs exist solely to parse the specific JSON structure provided.
// They are mapped immediately to the SwiftData models (Bird, Watchlist) and then discarded.

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
