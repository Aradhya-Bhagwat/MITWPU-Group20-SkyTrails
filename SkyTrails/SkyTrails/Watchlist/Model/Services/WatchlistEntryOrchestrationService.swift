import Foundation
import CoreLocation

/// Service responsible for orchestrating the complex logic of saving or updating watchlist entries
@MainActor
final class WatchlistEntryOrchestrationService {
    
    private let mutator: WatchlistEntryMutating
    
    init(mutator: WatchlistEntryMutating) {
        self.mutator = mutator
    }
    
    /// Parameters for saving an entry
    struct SaveParameters {
        let entry: WatchlistEntry?
        let bird: Bird?
        let birdName: String?
        let watchlistId: UUID?
        let notes: String?
        let location: LocationService.LocationData?
        let observationDate: Date?
        let endDate: Date?
        let photoName: String?
        let asObserved: Bool
        let shouldUseRuleMatching: Bool
    }
    
    /// Result of a save operation
    struct SaveResult {
        let success: Bool
        let bird: Bird?
        let error: Error?
        let noMatchingWatchlists: Bool
    }
    
    /// Orchestrates saving an entry, handling updates, rule matching, and photo attachment
    func saveEntry(params: SaveParameters) async -> SaveResult {
        // Handle updating existing entry
        if let existingEntry = params.entry {
            do {
                if !params.asObserved {
                    try mutator.updateEntryDates(
                        entryId: existingEntry.id,
                        startDate: params.observationDate,
                        endDate: params.endDate
                    )
                }
                
                try mutator.updateEntry(
                    entryId: existingEntry.id,
                    notes: params.notes,
                    observationDate: params.asObserved ? params.observationDate : nil,
                    lat: params.location?.lat,
                    lon: params.location?.lon,
                    locationDisplayName: params.location?.displayName
                )
                
                if let photoName = params.photoName {
                    try mutator.attachPhoto(entryId: existingEntry.id, imageName: photoName)
                }
                
                return SaveResult(success: true, bird: existingEntry.bird, error: nil, noMatchingWatchlists: false)
            } catch {
                return SaveResult(success: false, bird: existingEntry.bird, error: error, noMatchingWatchlists: false)
            }
        }
        
        // Handle creating new entry
        let birdToUse: Bird
        if let existingBird = params.bird {
            birdToUse = existingBird
        } else if let name = params.birdName, !name.isEmpty, let found = mutator.findBird(byName: name) {
            birdToUse = found
        } else if let name = params.birdName, !name.isEmpty {
            birdToUse = mutator.createBird(name: name)
        } else {
            return SaveResult(success: false, bird: nil, error: NSError(domain: "WatchlistOrchestration", code: 1, userInfo: [NSLocalizedDescriptionKey: "No bird provided"]), noMatchingWatchlists: false)
        }
        
        do {
            let clLocation = params.location.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            
            if params.shouldUseRuleMatching {
                let matchedWatchlistIds = try mutator.addBirdWithRuleMatching(
                    bird: birdToUse,
                    location: clLocation,
                    observationDate: params.observationDate,
                    notes: params.notes,
                    asObserved: params.asObserved
                )
                
                if !params.asObserved {
                     for watchlistId in matchedWatchlistIds {
                         if let entry = try? mutator.findEntry(birdId: birdToUse.bird_id, watchlistId: watchlistId) {
                             try mutator.updateEntryDates(entryId: entry.id, startDate: params.observationDate, endDate: params.endDate)
                         }
                     }
                }
                
                if let photoName = params.photoName {
                    for watchlistId in matchedWatchlistIds {
                        if let entry = try? mutator.findEntry(birdId: birdToUse.bird_id, watchlistId: watchlistId) {
                            try mutator.attachPhoto(entryId: entry.id, imageName: photoName)
                        }
                    }
                }
            } else {
                guard let targetWatchlistId = params.watchlistId else {
                    return SaveResult(success: false, bird: birdToUse, error: NSError(domain: "WatchlistOrchestration", code: 2, userInfo: [NSLocalizedDescriptionKey: "No target watchlist ID"]), noMatchingWatchlists: false)
                }
                
                try mutator.addBirds([birdToUse], to: targetWatchlistId, asObserved: params.asObserved)
                
                if let newEntry = try? mutator.findEntry(birdId: birdToUse.bird_id, watchlistId: targetWatchlistId) {
                    if !params.asObserved {
                        try mutator.updateEntryDates(entryId: newEntry.id, startDate: params.observationDate, endDate: params.endDate)
                    }
                    
                    try mutator.updateEntry(
                        entryId: newEntry.id,
                        notes: params.notes,
                        observationDate: params.asObserved ? params.observationDate : nil,
                        lat: clLocation?.latitude,
                        lon: clLocation?.longitude,
                        locationDisplayName: params.location?.displayName
                    )
                    
                    if let photoName = params.photoName {
                        try mutator.attachPhoto(entryId: newEntry.id, imageName: photoName)
                    }
                }
            }
            
            return SaveResult(success: true, bird: birdToUse, error: nil, noMatchingWatchlists: false)
        } catch WatchlistError.noMatchingWatchlists {
            return SaveResult(success: false, bird: birdToUse, error: WatchlistError.noMatchingWatchlists, noMatchingWatchlists: true)
        } catch {
            return SaveResult(success: false, bird: birdToUse, error: error, noMatchingWatchlists: false)
        }
    }
}
