
import Foundation
import SwiftData

struct WatchlistSeeder {
	private struct JSONWatchlistDTO: Codable {
		let id: UUID
		let title: String
		let location: String
		let startDate: TimeInterval
		let endDate: TimeInterval
		let observedBirds: [JSONBirdDTO]
		let toObserveBirds: [JSONBirdDTO]
	}
	
	private struct JSONSharedWatchlistDTO: Codable {
		let id: UUID
		let title: String
		let location: String
		let dateRange: String
		let startDate: TimeInterval?
		let endDate: TimeInterval?
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
		let location: [String]
		let date: [TimeInterval]
		let observedBy: [String]?
	}
	@MainActor
	static func seed(context: ModelContext) throws {
		let seedWatchlistsEnabled = Bundle.main.object(forInfoDictionaryKey: "SEED_WATCHLISTS") as? Bool ?? false
		guard seedWatchlistsEnabled else {
			return
		}
		let descriptor = FetchDescriptor<Watchlist>()
		let count = try context.fetchCount(descriptor)
		
		guard count == 0 else {
			return
		}
		do {
			try seedCustomWatchlists(context: context)
		} catch {
			throw SeederError.seedingFailed("Custom watchlists", error)
		}
		do {
			try seedSharedWatchlists(context: context)
		} catch {
			throw SeederError.seedingFailed("Shared watchlists", error)
		}
        do {
            let descriptor = FetchDescriptor<Watchlist>()
            let _ = try context.fetch(descriptor)
        } catch {
        }
		do {
			try context.save()
		} catch {
			throw SeederError.saveFailed(error)
		}
		_ = try context.fetchCount(descriptor)
	}
	
	@MainActor
	private static func seedCustomWatchlists(context: ModelContext) throws {
		guard let url = Bundle.main.url(forResource: "watchlists", withExtension: "json") else {
			throw SeederError.fileNotFound("watchlists.json")
		}
		let data = try Data(contentsOf: url)
		let dtos = try JSONDecoder().decode([JSONWatchlistDTO].self, from: data)
		for (index, dto) in dtos.enumerated() {
			let type: WatchlistType = .custom
			
			let watchlist = Watchlist(
				watchlist_id: dto.id,
				type: type,
				title: dto.title,
				location: dto.location,
				startDate: Date(timeIntervalSinceReferenceDate: dto.startDate),
				endDate: Date(timeIntervalSinceReferenceDate: dto.endDate)
			)
			
			context.insert(watchlist)
			
			let observedCount = dto.observedBirds.count
			let toObserveCount = dto.toObserveBirds.count
			processBirds(dto.observedBirds, for: watchlist, status: .observed, context: context)
			processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe, context: context)
            watchlist.observedCount = observedCount
            watchlist.speciesCount = observedCount + toObserveCount
            watchlist.updateCoverImage()
		}
	}
	
	@MainActor
	private static func seedSharedWatchlists(context: ModelContext) throws {
		guard let url = Bundle.main.url(forResource: "sharedWatchlists", withExtension: "json") else {
			throw SeederError.fileNotFound("sharedWatchlists.json")
		}
		let data = try Data(contentsOf: url)
		let dtos = try JSONDecoder().decode([JSONSharedWatchlistDTO].self, from: data)
		for (index, dto) in dtos.enumerated() {
			let watchlist = Watchlist(
				watchlist_id: dto.id,
				type: .shared,
				title: dto.title,
				location: dto.location,
				startDate: dto.startDate.map { Date(timeIntervalSinceReferenceDate: $0) },
				endDate: dto.endDate.map { Date(timeIntervalSinceReferenceDate: $0) }
			)
			
			context.insert(watchlist)
			
			let observedCount = dto.observedBirds.count
			let toObserveCount = dto.toObserveBirds.count
			processBirds(dto.observedBirds, for: watchlist, status: .observed, context: context)
			processBirds(dto.toObserveBirds, for: watchlist, status: .to_observe, context: context)
            watchlist.observedCount = observedCount
            watchlist.speciesCount = observedCount + toObserveCount
            watchlist.updateCoverImage()
		}
	}
	
	@MainActor
	private static func processBirds(_ birdDTOs: [JSONBirdDTO], for watchlist: Watchlist, status: WatchlistEntryStatus, context: ModelContext) {
		for dto in birdDTOs {
			let bird = findOrCreateBird(from: dto, in: context)
			
			let entry = WatchlistEntry(
				watchlist: watchlist,
				bird: bird,
				status: status,
				observedBy: dto.observedBy?.first
			)
            if status == .to_observe {
                entry.notify_upcoming = true
            }
			
			if status == .observed, let dateInterval = dto.date.first {
				entry.observationDate = Date(timeIntervalSinceReferenceDate: dateInterval)
			}
			
			context.insert(entry)
		}
	}
	
	@MainActor
	private static func findOrCreateBird(from dto: JSONBirdDTO, in context: ModelContext) -> Bird {
		let id = dto.id
		let descriptor = FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
			bird.bird_id == id
		})
		if let existing = try? context.fetch(descriptor).first {
			return existing
		}
		let name = dto.name
		let nameDescriptor = FetchDescriptor<Bird>(predicate: #Predicate<Bird> { bird in
			bird.commonName == name
		})
		if let existingByName = try? context.fetch(nameDescriptor).first {
			return existingByName
		}
		let placeholder = Bird(bird_id: dto.id,
			commonName: dto.name,
			scientificName: dto.scientificName,
			staticImageName: dto.images.first ?? "placeholder",
			validLocations: dto.location
		)
		context.insert(placeholder)
		return placeholder
	}
	
	enum SeederError: Error, LocalizedError {
		case fileNotFound(String)
		case seedingFailed(String, Error)
		case saveFailed(Error)
		
		var errorDescription: String? {
			switch self {
				case .fileNotFound(let filename):
					return "Seed file not found: \(filename)"
				case .seedingFailed(let type, let error):
					return "Failed to seed \(type): \(error.localizedDescription)"
				case .saveFailed(let error):
					return "Failed to save seeded data: \(error.localizedDescription)"
			}
		}
	}
}
