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
    /// TODO: Implement actual query using HotspotSpeciesPresence join model
    func getBirdsPresent(
        at location: CLLocationCoordinate2D,
        duringWeek week: Int,
        radiusInKm: Double = 10.0
    ) -> [Bird] {
        print("⚠️ [HotspotManager] getBirdsPresent() not yet implemented")
        print("⚠️ [HotspotManager] - Location: \(location)")
        print("⚠️ [HotspotManager] - Week: \(week)")
        print("⚠️ [HotspotManager] - Radius: \(radiusInKm)km")
        
        // TODO: Implement actual query:
        // 1. Find hotspots within radius of location
        // 2. Get HotspotSpeciesPresence records for those hotspots
        // 3. Filter by week
        // 4. Return unique birds
        
        return []
    }
}

// MARK: - Placeholder Models
// These should be defined in separate files once Hotspot feature is implemented

@Model
final class Hotspot {
    @Attribute(.unique)
    var id: UUID
    
    var name: String
    var locality: String?
    var lat: Double
    var lon: Double
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HotspotSpeciesPresence.hotspot)
    var speciesList: [HotspotSpeciesPresence]?
    
    init(id: UUID = UUID(), name: String, locality: String? = nil, lat: Double, lon: Double) {
        self.id = id
        self.name = name
        self.locality = locality
        self.lat = lat
        self.lon = lon
    }
}

@Model
final class HotspotSpeciesPresence {
    @Attribute(.unique)
    var id: UUID
    
    var hotspot: Hotspot?
    var bird: Bird?
    
    // Seasonality data
    var validWeeks: [Int]? // Week numbers when species is present
    var probability: Int? // Likelihood of sighting (0-100)
    
    init(id: UUID = UUID(), hotspot: Hotspot? = nil, bird: Bird? = nil, validWeeks: [Int]? = nil, probability: Int? = nil) {
        self.id = id
        self.hotspot = hotspot
        self.bird = bird
        self.validWeeks = validWeeks
        self.probability = probability
    }
}
