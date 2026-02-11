//
//  CommunityObservationManager.swift
//  SkyTrails
//
//  Stub implementation - needs full implementation
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class CommunityObservationManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get community observations near a location
    func getObservations(
        near location: CLLocationCoordinate2D,
        radiusInKm: Double = 50.0,
        maxAge: TimeInterval? = nil
    ) -> [CommunityObservation] {
        print("[homeseeder] 🔍 [CommunityObservationManager] Fetching observations...")
        
        // 1. Base Descriptor
        var descriptor = FetchDescriptor<CommunityObservation>(
            sortBy: [SortDescriptor(\.observedAt, order: .reverse)]
        )
        
        // 2. Filter by date if needed (Predicate)
        if let maxAge = maxAge {
            let cutoffDate = Date().addingTimeInterval(-maxAge)
            descriptor.predicate = #Predicate { obs in
                obs.observedAt >= cutoffDate
            }
        }
        
        // 3. Fetch
        guard let allObservations = try? modelContext.fetch(descriptor) else {
            print("[homeseeder] ❌ [CommunityObservationManager] Fetch failed")
            return []
        }
        
        print("[homeseeder] 📊 [CommunityObservationManager] Fetched \(allObservations.count) potential observations")
        
        // 4. Filter by location (In-memory)
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        let filtered = allObservations.filter { obs in
            guard let lat = obs.lat, let lon = obs.lon else { return false }
            let obsLoc = CLLocation(latitude: lat, longitude: lon)
            return obsLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        print("[homeseeder] 📍 [CommunityObservationManager] \(filtered.count) observations within \(radiusInKm)km of \(location)")
        
        return filtered
    }
}
