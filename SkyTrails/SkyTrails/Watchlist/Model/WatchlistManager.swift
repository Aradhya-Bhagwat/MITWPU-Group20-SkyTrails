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
	let context: ModelContext  // Made internal for HomeManager access
	
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
				Bird.self,
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
			
			let hasSeededKey = "kAppHasSeededData_v1"
			if !UserDefaults.standard.bool(forKey: hasSeededKey) {
				print("🗑️ [WatchlistManager] First launch or reset: clearing and seeding database...")
				
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
				
				// Perform Seeding
				do {
					try WatchlistSeeder.seed(context: context)
					UserDefaults.standard.set(true, forKey: hasSeededKey)
					print("✅ [WatchlistManager] Seeding completed successfully")
				} catch {
					print("❌ [WatchlistManager] Seeding failed: \(error)")
					// Don't fatal error - allow app to continue
				}
			} else {
				print("ℹ️ [WatchlistManager] Database already seeded. Skipping wipe.")
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
		let customLists = allLists.filter { $0.type == .custom }.map { WatchlistMapper.toDTO($0) }
		let sharedLists = allLists.filter { $0.type == .shared }.map { WatchlistMapper.toDTO($0) }
		
		print("📊 [WatchlistManager] Custom: \(customLists.count), Shared: \(sharedLists.count)")
		
			// Build My Watchlist (Virtual Aggregation)
		let myWatchlist = WatchlistMapper.buildMyWatchlistDTO(from: allLists)
		
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
		return WatchlistConstants.myWatchlistID
	}
	
	func getPersonalWatchlists() -> [Watchlist] {
		return fetchWatchlists(type: .custom)
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
		let myWatchlistId = WatchlistConstants.myWatchlistID
		
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
		let myWatchlistId = WatchlistConstants.myWatchlistID
		
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
	
	func saveContext() {
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
		let myWatchlistId = WatchlistConstants.myWatchlistID
		
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
		let myWatchlistId = WatchlistConstants.myWatchlistID
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
	//
	//  WatchlistManager+Queries.swift
	//  SkyTrails
	//
	//  Integration queries for Hotspot, Migration, and Upcoming Birds
	//
extension WatchlistManager {
	
		// MARK: - Upcoming Birds (Home Module Integration)
	
		/// Get birds the user should be notified about based on:
		/// - They're on watchlist with notify_upcoming enabled
		/// - They're present at user's location during current/upcoming weeks
	func getUpcomingBirds(
		userLocation: CLLocationCoordinate2D,
		currentWeek: Int,
		lookAheadWeeks: Int = 4,
		radiusInKm: Double = 50.0
	) -> [UpcomingBirdResult] {
		
		print("🔔 [WatchlistManager] Getting upcoming birds...")
		print("🔔 [WatchlistManager] - Location: \(userLocation)")
		print("🔔 [WatchlistManager] - Current week: \(currentWeek)")
		print("🔔 [WatchlistManager] - Look ahead: \(lookAheadWeeks) weeks")
		
			// 1. Get all watchlist entries with notifications enabled
		let descriptor = FetchDescriptor<WatchlistEntry>(
			predicate: #Predicate { entry in
				entry.notify_upcoming == true && entry.status.rawValue == "to_observe"
			}
		)
		
		guard let notifyEntries = try? context.fetch(descriptor) else {
			print("❌ [WatchlistManager] Failed to fetch notify entries")
			return []
		}
		
		print("📊 [WatchlistManager] Found \(notifyEntries.count) entries with notifications enabled")
		
			// 2. For each bird, check if it's present at user's location
		var results: [UpcomingBirdResult] = []
		let hotspotManager = HotspotManager(modelContext: context)
		
		for entry in notifyEntries {
			guard let bird = entry.bird else { continue }
			
				// Check weeks in the upcoming window
			for weekOffset in 0...lookAheadWeeks {
				let checkWeek = ((currentWeek + weekOffset - 1) % 52) + 1 // Wrap around year
				
				let presentBirds = hotspotManager.getBirdsPresent(
					at: userLocation,
					duringWeek: checkWeek,
					radiusInKm: radiusInKm
				)
				
				if presentBirds.contains(where: { $0.id == bird.id }) {
					results.append(UpcomingBirdResult(
						bird: bird,
						entry: entry,
						expectedWeek: checkWeek,
						daysUntil: weekOffset * 7
					))
					print("✅ [WatchlistManager] \(bird.commonName) arriving in \(weekOffset) weeks")
					break // Only add each bird once
				}
			}
		}
		
		print("🔔 [WatchlistManager] Found \(results.count) upcoming birds")
		return results.sorted { $0.daysUntil < $1.daysUntil }
	}
	
		/// Alternative: Get upcoming birds using saved home location preference
	func getUpcomingBirdsAtHome(
		lookAheadWeeks: Int = 4,
		radiusInKm: Double = 50.0
	) -> [UpcomingBirdResult] {
		
			// Get home location from UserDefaults or LocationService
		guard let homeLocation = LocationPreferences.shared.homeLocation else {
			print("⚠️ [WatchlistManager] No home location set")
			return []
		}
		
		let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
		
		return getUpcomingBirds(
			userLocation: homeLocation,
			currentWeek: currentWeek,
			lookAheadWeeks: lookAheadWeeks,
			radiusInKm: radiusInKm
		)
	}
	
		// MARK: - Location-Based Queries
	
		/// Get entries observed within radius of a location
	func getEntriesObservedNear(
		location: CLLocationCoordinate2D,
		radiusInKm: Double = 10.0,
		watchlistId: UUID? = nil
	) -> [WatchlistEntry] {
		
		let descriptor = FetchDescriptor<WatchlistEntry>(
			predicate: #Predicate { entry in
				entry.status.rawValue == "observed" && entry.lat != nil && entry.lon != nil
			}
		)
		
		guard let allObserved = try? context.fetch(descriptor) else { return [] }
		
			// Filter by watchlist if specified
		var filtered = allObserved
		if let watchlistId = watchlistId {
			filtered = filtered.filter { $0.watchlist?.id == watchlistId }
		}
		
			// Geospatial filter
		let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
		return filtered.filter { entry in
			guard let lat = entry.lat, let lon = entry.lon else { return false }
			let entryLoc = CLLocation(latitude: lat, longitude: lon)
			return entryLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
		}
	}
	
		// MARK: - Date Range Queries
	
		/// Get birds the user should be looking for during a date range
	func getEntriesInDateRange(
		start: Date,
		end: Date,
		watchlistId: UUID? = nil
	) -> [WatchlistEntry] {
		
		let descriptor = FetchDescriptor<WatchlistEntry>(
			predicate: #Predicate { entry in
				entry.status.rawValue == "to_observe"
			}
		)
		
		guard let entries = try? context.fetch(descriptor) else { return [] }
		
		var filtered = entries
		
			// Filter by watchlist
		if let watchlistId = watchlistId {
			filtered = filtered.filter { $0.watchlist?.id == watchlistId }
		}
		
			// Filter by date range overlap
		return filtered.filter { entry in
			guard let rangeStart = entry.toObserveStartDate,
				  let rangeEnd = entry.toObserveEndDate else {
				return false
			}
			
				// Check if ranges overlap
			return rangeStart <= end && rangeEnd >= start
		}
	}
	
		/// Get entries to observe THIS WEEK
	func getEntriesForThisWeek(watchlistId: UUID? = nil) -> [WatchlistEntry] {
		let calendar = Calendar.current
		guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
			  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
			return []
		}
		
		return getEntriesInDateRange(start: weekStart, end: weekEnd, watchlistId: watchlistId)
	}
}

	// MARK: - Result Types

struct UpcomingBirdResult: Identifiable {
	let id = UUID()
	let bird: Bird
	let entry: WatchlistEntry
	let expectedWeek: Int
	let daysUntil: Int
	
	var isArriving: Bool { daysUntil <= 7 }
	var isPresentNow: Bool { daysUntil == 0 }
	var statusText: String {
		if isPresentNow { return "Here now!" }
		if isArriving { return "Arriving this week" }
		if daysUntil <= 14 { return "Arriving in \(daysUntil) days" }
		return "Expected in \(daysUntil / 7) weeks"
	}
}
