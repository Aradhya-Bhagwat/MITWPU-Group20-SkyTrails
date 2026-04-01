import Foundation
import CoreLocation

/// Protocol for querying watchlist data - enables unit testing of filtering logic
protocol WatchlistQuerying {
    func fetchWatchlists(type: WatchlistType?) throws -> [Watchlist]
    func fetchEntries(watchlistID: UUID, status: WatchlistEntryStatus?) throws -> [WatchlistEntry]
    func getWatchlist(by id: UUID) throws -> Watchlist?
    func fetchAllBirds() -> [Bird]
}

/// Protocol for mutating watchlist entries - enables unit testing of orchestration logic
protocol WatchlistEntryMutating {
    func updateEntry(entryId: UUID, notes: String?, observationDate: Date?, lat: Double?, lon: Double?, locationDisplayName: String?) throws
    func updateEntryDates(entryId: UUID, startDate: Date?, endDate: Date?) throws
    func attachPhoto(entryId: UUID, imageName: String) throws
    func findBird(byName name: String) -> Bird?
    func createBird(name: String) -> Bird
    func addBirdWithRuleMatching(bird: Bird, location: CLLocationCoordinate2D?, observationDate: Date?, notes: String?, asObserved: Bool) throws -> [UUID]
    func findEntry(birdId: UUID, watchlistId: UUID) throws -> WatchlistEntry?
    func addBirds(_ birds: [Bird], to watchlistId: UUID, asObserved: Bool) throws
}

// MARK: - WatchlistManager conformance

extension WatchlistManager: WatchlistQuerying {}
extension WatchlistManager: WatchlistEntryMutating {}