import Foundation
import CoreLocation
import SwiftData

/// Service responsible for orchestrating the complex logic of saving or updating watchlist entries
@MainActor
final class WatchlistEntryOrchestrationService {
    
    private weak var manager: WatchlistManager?
    
    init(manager: WatchlistManager? = nil) {
        self.manager = manager
    }
    
    func setManager(_ manager: WatchlistManager) {
        self.manager = manager
    }
    
    /// Parameters for saving an entry
    struct SaveParameters {
        let entry: WatchlistEntry?
        let bird: Bird?
        let birdName: String?
        let watchlistId: UUID?
        let notes: String?
        let location: LocationService.LocationData?
        let observationDate: Date? // Used for observed, or as start date for unobserved
        let endDate: Date? // Only for unobserved
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
        guard let manager = manager else {
            return SaveResult(success: false, bird: nil, error: NSError(domain: "WatchlistOrchestration", code: 0, userInfo: [NSLocalizedDescriptionKey: "Manager not set"]), noMatchingWatchlists: false)
        }
        
        // Handle updating existing entry
        if let existingEntry = params.entry {
            do {
                if !params.asObserved {
                    // Unobserved date updates
                    try manager.updateEntryDates(
                        entryId: existingEntry.id,
                        startDate: params.observationDate,
                        endDate: params.endDate
                    )
                }
                
                try manager.updateEntry(
                    entryId: existingEntry.id,
                    notes: params.notes,
                    observationDate: params.asObserved ? params.observationDate : nil,
                    lat: params.location?.lat,
                    lon: params.location?.lon,
                    locationDisplayName: params.location?.displayName
                )
                
                if let photoName = params.photoName {
                    try manager.attachPhoto(entryId: existingEntry.id, imageName: photoName)
                }
                
                // Invalidate cache and post notification for UI update
                manager.invalidateMyWatchlistCache()
                NotificationCenter.default.post(name: .watchlistDataDidChange, object: nil)
                
                return SaveResult(success: true, bird: existingEntry.bird, error: nil, noMatchingWatchlists: false)
            } catch {
                return SaveResult(success: false, bird: existingEntry.bird, error: error, noMatchingWatchlists: false)
            }
        }
        
        // Handle creating new entry
        let birdToUse: Bird
        if let existingBird = params.bird {
            birdToUse = existingBird
        } else if let name = params.birdName, !name.isEmpty, let found = manager.findBird(byName: name) {
            birdToUse = found
        } else if let name = params.birdName, !name.isEmpty {
            birdToUse = manager.createBird(name: name)
        } else {
            return SaveResult(success: false, bird: nil, error: NSError(domain: "WatchlistOrchestration", code: 1, userInfo: [NSLocalizedDescriptionKey: "No bird provided"]), noMatchingWatchlists: false)
        }
        
        do {
            let clLocation = params.location.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            
            if params.shouldUseRuleMatching {
                let matchedWatchlistIds = try manager.addBirdWithRuleMatching(
                    bird: birdToUse,
                    location: clLocation,
                    observationDate: params.observationDate,
                    notes: params.notes,
                    asObserved: params.asObserved
                )
                
                // For unobserved rule matching, update dates
                if !params.asObserved {
                     for watchlistId in matchedWatchlistIds {
                         if let entry = try? manager.findEntry(birdId: birdToUse.bird_id, watchlistId: watchlistId) {
                             try manager.updateEntryDates(entryId: entry.id, startDate: params.observationDate, endDate: params.endDate)
                         }
                     }
                }
                
                if let photoName = params.photoName {
                    for watchlistId in matchedWatchlistIds {
                        if let entry = try? manager.findEntry(birdId: birdToUse.bird_id, watchlistId: watchlistId) {
                            try manager.attachPhoto(entryId: entry.id, imageName: photoName)
                        }
                    }
                }
                
                // Ensure all changes are persisted
                try? manager.context.save()
            } else {
                guard let targetWatchlistId = params.watchlistId else {
                    return SaveResult(success: false, bird: birdToUse, error: NSError(domain: "WatchlistOrchestration", code: 2, userInfo: [NSLocalizedDescriptionKey: "No target watchlist ID"]), noMatchingWatchlists: false)
                }
                
                try manager.addBirds([birdToUse], to: targetWatchlistId, asObserved: params.asObserved)
                
                if let newEntry = try? manager.findEntry(birdId: birdToUse.bird_id, watchlistId: targetWatchlistId) {
                    if !params.asObserved {
                        try manager.updateEntryDates(entryId: newEntry.id, startDate: params.observationDate, endDate: params.endDate)
                    }
                    
                    try manager.updateEntry(
                        entryId: newEntry.id,
                        notes: params.notes,
                        observationDate: params.asObserved ? params.observationDate : nil,
                        lat: clLocation?.latitude,
                        lon: clLocation?.longitude,
                        locationDisplayName: params.location?.displayName
                    )
                    
                    if let photoName = params.photoName {
                        try manager.attachPhoto(entryId: newEntry.id, imageName: photoName)
                    }
                }
                
                // Ensure all changes are persisted
                try? manager.context.save()
            }
            
            // Invalidate cache and post notification for UI update
            manager.invalidateMyWatchlistCache()
            NotificationCenter.default.post(name: .watchlistDataDidChange, object: nil)
            
            return SaveResult(success: true, bird: birdToUse, error: nil, noMatchingWatchlists: false)
        } catch WatchlistError.noMatchingWatchlists {
            return SaveResult(success: false, bird: birdToUse, error: WatchlistError.noMatchingWatchlists, noMatchingWatchlists: true)
        } catch {
            return SaveResult(success: false, bird: birdToUse, error: error, noMatchingWatchlists: false)
        }
    }
}
