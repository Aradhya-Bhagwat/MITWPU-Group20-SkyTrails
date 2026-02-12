//
//  HotspotManager.swift
//  SkyTrails
//
//  Stub implementation - needs full implementation
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class HotspotManager {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Get birds present at a location during a specific week
    func getBirdsPresent(
        at location: CLLocationCoordinate2D,
        duringWeek week: Int,
        radiusInKm: Double = 50.0
    ) -> [Bird] {
        print("[homeseeder] 🔍 [HotspotManager] Finding birds at \(location.latitude), \(location.longitude) for week \(week)")
        
        // 1. Fetch all hotspots (spatial query optimization would happen here in production)
        let descriptor = FetchDescriptor<Hotspot>()
        guard let allHotspots = try? modelContext.fetch(descriptor) else {
            print("[homeseeder] ❌ [HotspotManager] Failed to fetch hotspots")
            return []
        }
        
        // 2. Filter hotspots by radius
        let queryLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let nearbyHotspots = allHotspots.filter { hotspot in
            let hotspotLoc = CLLocation(latitude: hotspot.lat, longitude: hotspot.lon)
            return hotspotLoc.distance(from: queryLoc) <= (radiusInKm * 1000)
        }
        
        print("[homeseeder] 📍 [HotspotManager] Found \(nearbyHotspots.count) hotspots within \(radiusInKm)km")
        
        // 3. Aggregate birds present this week
        var uniqueBirds: Set<Bird> = []
        
        for hotspot in nearbyHotspots {
            guard let speciesList = hotspot.speciesList else { continue }
            
            for presence in speciesList {
                // Check if bird is present this week
                if let weeks = presence.validWeeks, weeks.contains(week), let bird = presence.bird {
                    uniqueBirds.insert(bird)
                }
            }
        }
        
        print("[homeseeder] 🦜 [HotspotManager] Found \(uniqueBirds.count) unique bird species present")
        
        return Array(uniqueBirds)
    }
}
