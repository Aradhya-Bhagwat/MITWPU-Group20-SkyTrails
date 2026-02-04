	//
	//  WatchlistManager.swift
	//  SkyTrails
	//
	//  Created by SDC-USER on 15/12/25.
	//

import Foundation
import CoreLocation
import MapKit
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
			print("🗑️ [WatchlistManager] Force clearing database for fresh seed...")
			let descriptor = FetchDescriptor<Watchlist>()
			if let existing = try? context.fetch(descriptor) {
				existing.forEach { context.delete($0) }
			}
			
			let birdDescriptor = FetchDescriptor<Bird>()
			if let existingBirds = try? context.fetch(birdDescriptor) {
				existingBirds.forEach { context.delete($0) }
				print("✅ [WatchlistManager] Cleared \(existingBirds.count) existing birds")
			}
			
			try? context.save()
			print("✅ [WatchlistManager] Cleared watchlists and birds")
			
				// 2. Perform Seeding
			do {
				try WatchlistSeeder.seed(context: context)
				print("✅ [WatchlistManager] Seeding completed successfully")
			} catch {
				print("❌ [WatchlistManager] Seeding failed: \(error)")
				print("⚠️ [WatchlistManager] Continuing with empty/existing database")
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
		
		print("📊 [WatchlistManager] Loading dashboard data...")
		
			// Fetch All
		let descriptor = FetchDescriptor<Watchlist>(sortBy: [SortDescriptor(\.created_at, order: .reverse)])
		let allLists = try context.fetch(descriptor)
		
		print("📊 [WatchlistManager] Fetched \(allLists.count) total watchlists")
		
			// Filter & Map
		let customLists = allLists.filter { $0.type == .custom }.map { toDTO($0) }
		let sharedLists = allLists.filter { $0.type == .shared }.map { toDTO($0) }
		
		print("📊 [WatchlistManager] Custom: \(customLists.count), Shared: \(sharedLists.count)")
		
			// Build My Watchlist (Virtual Aggregation)
		let myWatchlist = buildMyWatchlistDTO(from: allLists)
		
		print("📊 [WatchlistManager] My Watchlist: \(myWatchlist.stats.observedCount)/\(myWatchlist.stats.totalCount)")
		
			// Calculate Global Stats
		let allEntries = allLists.flatMap { $0.entries ?? [] }
		let observedCount = allEntries.filter { $0.status == .observed }.count
		let rareCount = allEntries.filter {
			$0.status == .observed &&
			($0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare)
		}.count
		let totalCount = allEntries.count
		
		let globalStats = WatchlistStatsDTO(
			observedCount: observedCount,
			totalCount: totalCount,
			rareCount: rareCount
		)
		
		print("📊 [WatchlistManager] Global Stats: \(observedCount)/\(totalCount) (Rare: \(rareCount))")
		
		return (myWatchlist, customLists, sharedLists, globalStats)
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
			// My Watchlist is now virtual, return special ID
		return UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
	}
	
	func getPersonalWatchlists() -> [Watchlist] {
		return fetchWatchlists(type: .custom)
	}
	
		// MARK: - My Watchlist Builder
	
	private func buildMyWatchlistDTO(from allLists: [Watchlist]) -> WatchlistSummaryDTO {
			// Aggregate ALL entries from ALL watchlists
		let allEntries = allLists.flatMap { $0.entries ?? [] }
		
			// Remove duplicates by bird ID (keep observed status if exists)
		var uniqueEntries: [UUID: WatchlistEntry] = [:]
		for entry in allEntries {
			if let birdId = entry.bird?.id {
				if let existing = uniqueEntries[birdId] {
						// Prefer observed status
					if entry.status == .observed && existing.status != .observed {
						uniqueEntries[birdId] = entry
					}
				} else {
					uniqueEntries[birdId] = entry
				}
			}
		}
		
		let uniqueEntriesArray = Array(uniqueEntries.values)
		
			// Calculate stats
		let observedCount = uniqueEntriesArray.filter { $0.status == .observed }.count
		let totalCount = uniqueEntriesArray.count
		let rareCount = uniqueEntriesArray.filter {
			$0.status == .observed &&
			($0.bird?.rarityLevel == .rare || $0.bird?.rarityLevel == .very_rare)
		}.count
		
		let stats = WatchlistStatsDTO(
			observedCount: observedCount,
			totalCount: totalCount,
			rareCount: rareCount
		)
		
			// Get preview images (up to 4 unique birds)
		let previewImages = uniqueEntriesArray
			.compactMap { $0.bird?.staticImageName }
			.prefix(4)
			.map { String($0) }
		
		return WatchlistSummaryDTO(
			id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, // Special ID
			title: "My Watchlist",
			subtitle: "All Birds",
			dateText: "",
			image: previewImages.first,
			previewImages: Array(previewImages),
			stats: stats,
			type: .my_watchlist
		)
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
		print("🔍 [WatchlistManager] fetchEntries() called")
		print("🔍 [WatchlistManager] - Watchlist ID: \(watchlistID)")
		print("🔍 [WatchlistManager] - Filter by status: \(status?.rawValue ?? "all")")
		
			// Special handling for My Watchlist virtual ID
		let myWatchlistId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
		
		if watchlistID == myWatchlistId {
			print("📋 [WatchlistManager] Fetching from My Watchlist (virtual aggregation)")
				// Return ALL entries from ALL watchlists
			let allLists = fetchWatchlists()
			var allEntries = allLists.flatMap { $0.entries ?? [] }
			print("📊 [WatchlistManager] Total entries across all watchlists: \(allEntries.count)")
			
			if let status = status {
				allEntries = allEntries.filter { $0.status == status }
				print("📊 [WatchlistManager] After status filter (\(status.rawValue)): \(allEntries.count)")
			}
			
			return allEntries.sorted { $0.addedDate < $1.addedDate }
		}
		
		guard let watchlist = getWatchlist(by: watchlistID) else {
			print("❌ [WatchlistManager] Watchlist not found for ID: \(watchlistID)")
			return []
		}
		
		print("✅ [WatchlistManager] Watchlist found: '\(watchlist.title ?? "Untitled")'")
		var entries = watchlist.entries ?? []
		print("📊 [WatchlistManager] Total entries in watchlist: \(entries.count)")
		
		if let status = status {
			entries = entries.filter { $0.status == status }
			print("📊 [WatchlistManager] After status filter (\(status.rawValue)): \(entries.count)")
		}
		
		entries.forEach { entry in
			print("  - \(entry.bird?.commonName ?? "Unknown") [\(entry.status.rawValue)]")
		}
		
		return entries.sorted { $0.addedDate < $1.addedDate }
	}
	
	func fetchGlobalObservedCount() -> Int {
		let descriptor = FetchDescriptor<WatchlistEntry>()
		let allEntries = (try? context.fetch(descriptor)) ?? []
		return allEntries.filter { $0.status == .observed }.count
	}
	
	func getStats(for watchlistID: UUID) -> (observed: Int, total: Int) {
			// Special handling for My Watchlist virtual ID
		let myWatchlistId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
		
		if watchlistID == myWatchlistId {
			let allLists = fetchWatchlists()
			let allEntries = allLists.flatMap { $0.entries ?? [] }
			let total = allEntries.count
			let observed = allEntries.filter { $0.status == .observed }.count
			return (observed, total)
		}
		
		guard let watchlist = getWatchlist(by: watchlistID), let entries = watchlist.entries else { return (0, 0) }
		
		let total = entries.count
		let observed = entries.filter { $0.status == .observed }.count
		return (observed, total)
	}
	
	func getWatchlist(by id: UUID) -> Watchlist? {
		print("🔍 [WatchlistManager] getWatchlist() called for ID: \(id)")
		let descriptor = FetchDescriptor<Watchlist>(predicate: #Predicate<Watchlist> { watchlist in
			watchlist.id == id
		})
		
		do {
			let results = try context.fetch(descriptor)
			if let watchlist = results.first {
				print("✅ [WatchlistManager] Found watchlist: '\(watchlist.title ?? "Untitled")' with \(watchlist.entries?.count ?? 0) entries")
				return watchlist
			} else {
				print("❌ [WatchlistManager] No watchlist found for ID: \(id)")
				return nil
			}
		} catch {
			print("❌ [WatchlistManager] Fetch failed: \(error)")
			return nil
		}
	}
	
		// MARK: - CRUD Helpers
	
	private func saveContext() {
		do {
			print("💾 [WatchlistManager] Attempting to save context...")
			try context.save()
			print("✅ [WatchlistManager] Context saved successfully")
		} catch {
			print("❌ [WatchlistManager] SAVE FAILED: \(error)")
			print("❌ [WatchlistManager] Error details: \(error.localizedDescription)")
			if let nsError = error as NSError? {
				print("❌ [WatchlistManager] NSError domain: \(nsError.domain), code: \(nsError.code)")
				print("❌ [WatchlistManager] User info: \(nsError.userInfo)")
			}
		}
	}
	
		// MARK: - Operations
	
	func addWatchlist(title: String, location: String, startDate: Date, endDate: Date, type: WatchlistType = .custom, locationDisplayName: String? = nil) {
		let wl = Watchlist(title: title, location: location, locationDisplayName: locationDisplayName, startDate: startDate, endDate: endDate)
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
	
	func fetchAllBirds() -> [Bird] {
		let descriptor = FetchDescriptor<Bird>(sortBy: [SortDescriptor(\.commonName)])
		return (try? context.fetch(descriptor)) ?? []
	}
	
	func findBird(byName name: String) -> Bird? {
		let descriptor = FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
			bird.commonName == name
		})
		return try? context.fetch(descriptor).first
	}
	
	func createBird(name: String) -> Bird {
		print("🐦 [WatchlistManager] createBird() called for: '\(name)'")
		let bird = Bird(
			id: UUID(),
			commonName: name,
			scientificName: "Unknown",
			staticImageName: "photo",
			rarityLevel: .common,
			validLocations: []
		)
		print("💾 [WatchlistManager] Inserting new bird into context (ID: \(bird.id))")
		context.insert(bird)
		saveContext()
		print("✅ [WatchlistManager] Bird created successfully")
		return bird
	}
	
	func updateEntry(entryId: UUID, notes: String?, observationDate: Date?, lat: Double? = nil, lon: Double? = nil, locationDisplayName: String? = nil) {
		print("✏️  [WatchlistManager] updateEntry() called")
		print("✏️  [WatchlistManager] - Entry ID: \(entryId)")
		print("✏️  [WatchlistManager] - Notes: \(notes ?? "nil")")
		print("✏️  [WatchlistManager] - Observation Date: \(observationDate?.description ?? "nil")")
		
		let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate<WatchlistEntry> { entry in
			entry.id == entryId
		})
		
		do {
			let results = try context.fetch(descriptor)
			print("🔍 [WatchlistManager] Fetch results: \(results.count) entries found")
			
			if let entry = results.first {
				print("✅ [WatchlistManager] Entry found: \(entry.bird?.commonName ?? "Unknown bird")")
				print("📝 [WatchlistManager] Updating properties...")
				
				entry.notes = notes
				entry.observationDate = observationDate
				entry.lat = lat
				entry.lon = lon
				entry.locationDisplayName = locationDisplayName
				
				print("💾 [WatchlistManager] Saving changes...")
				saveContext()
			} else {
				print("❌ [WatchlistManager] Entry not found for ID: \(entryId)")
			}
		} catch {
			print("❌ [WatchlistManager] Fetch failed: \(error)")
		}
	}

	@available(*, deprecated, message: "Use LocationService.shared.reverseGeocode() instead")
	func lat_lon_to_Name(lat: Double, lon: Double) async -> String? {
		return await LocationService.shared.reverseGeocode(lat: lat, lon: lon)
	}
	
	func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) {
		print("🐦 [WatchlistManager] addBirds() called")
		print("🐦 [WatchlistManager] - Watchlist ID: \(watchlistId)")
		print("🐦 [WatchlistManager] - Birds to add: \(birds.count)")
		print("🐦 [WatchlistManager] - As observed: \(asObserved)")
		birds.forEach { print("🐦 [WatchlistManager] - Bird: \($0.commonName) (id: \($0.id))") }
		
		var targetWatchlistId = watchlistId
		let myWatchlistId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
		
		if watchlistId == myWatchlistId {
			print("⚠️ [WatchlistManager] Virtual 'My Watchlist' ID detected. resolving to real watchlist...")
			let customLists = fetchWatchlists(type: .custom)
			if let existing = customLists.first(where: { $0.title == "My Watchlist" }) {
				targetWatchlistId = existing.id
				print("✅ [WatchlistManager] Resolved to existing 'My Watchlist' (ID: \(existing.id))")
			} else if let first = customLists.first {
				targetWatchlistId = first.id
				print("✅ [WatchlistManager] Resolved to first available custom watchlist: '\(first.title ?? "Untitled")' (ID: \(first.id))")
			} else {
				print("⚠️ [WatchlistManager] No custom watchlists found. Creating 'My Watchlist'...")
				addWatchlist(title: "My Watchlist", location: "General", startDate: Date(), endDate: Date().addingTimeInterval(31536000))
					// Fetch it back
				if let newWl = fetchWatchlists(type: .custom).first(where: { $0.title == "My Watchlist" }) {
					targetWatchlistId = newWl.id
					print("✅ [WatchlistManager] Created and resolved to 'My Watchlist' (ID: \(newWl.id))")
				} else {
					print("❌ [WatchlistManager] CRITICAL: Failed to create fallback watchlist")
					return
				}
			}
		}
		
		guard let watchlist = getWatchlist(by: targetWatchlistId) else {
			print("❌ [WatchlistManager] FAILED: Watchlist not found for ID: \(targetWatchlistId)")
			return
		}
		
		print("✅ [WatchlistManager] Watchlist found: '\(watchlist.title ?? "Untitled")'")
		
		let existingEntries = watchlist.entries ?? []
		print("📊 [WatchlistManager] Existing entries in watchlist: \(existingEntries.count)")
		
		var addedCount = 0
		var skippedCount = 0
		
		for bird in birds {
			let alreadyExists = existingEntries.contains(where: { $0.bird?.id == bird.id })
			
			if alreadyExists {
				print("⏭️  [WatchlistManager] Skipping '\(bird.commonName)' - already exists in watchlist")
				skippedCount += 1
			} else {
				print("➕ [WatchlistManager] Creating entry for '\(bird.commonName)'")
				let entry = WatchlistEntry(
					watchlist: watchlist,
					bird: bird,
					status: asObserved ? .observed : .to_observe
				)
				if asObserved {
					entry.observationDate = Date()
					print("📅 [WatchlistManager] Set observation date to: \(Date())")
				}
				
				print("💾 [WatchlistManager] Inserting entry into context (ID: \(entry.id))")
				context.insert(entry)
				addedCount += 1
			}
		}
		
		print("📊 [WatchlistManager] Summary: Added \(addedCount), Skipped \(skippedCount)")
		
		if addedCount > 0 {
			print("💾 [WatchlistManager] Calling saveContext() for \(addedCount) new entries...")
			saveContext()
			
				// Verify entries were saved
			let afterSave = watchlist.entries ?? []
			print("✅ [WatchlistManager] After save: watchlist now has \(afterSave.count) entries")
		} else {
			print("⚠️  [WatchlistManager] No new entries to save")
		}
	}
	
		// MARK: - Photo Persistence
	
		/// Finds the entry for a specific bird inside a specific watchlist (used after addBirds to locate the new entry)
	func findEntry(birdId: UUID, watchlistId: UUID) -> WatchlistEntry? {
			// Resolve virtual My Watchlist ID the same way addBirds does
		var targetId = watchlistId
		let myWatchlistId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
		if watchlistId == myWatchlistId {
			let customLists = fetchWatchlists(type: .custom)
			if let existing = customLists.first(where: { $0.title == "My Watchlist" }) {
				targetId = existing.id
			} else if let first = customLists.first {
				targetId = first.id
			}
		}
		
		guard let watchlist = getWatchlist(by: targetId) else { return nil }
		return watchlist.entries?.first(where: { $0.bird?.id == birdId })
	}
	
		/// Creates an ObservedBirdPhoto record linking the on-disk file to the entry
	func attachPhoto(entryId: UUID, imageName: String) {
		let descriptor = FetchDescriptor<WatchlistEntry>(predicate: #Predicate<WatchlistEntry> { entry in
			entry.id == entryId
		})
		guard let entry = try? context.fetch(descriptor).first else {
			print("❌ [WatchlistManager] attachPhoto – entry not found: \(entryId)")
			return
		}
		let photo = ObservedBirdPhoto(watchlistEntry: entry, imagePath: imageName)
		context.insert(photo)
		saveContext()
		print("📸 [WatchlistManager] ObservedBirdPhoto created for entry \(entryId): \(imageName)")
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
