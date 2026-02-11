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

// MARK: - Placeholder Model
// This should be defined in a separate file once Community feature is implemented

@Model
final class CommunityObservation {
    @Attribute(.unique)
    var id: UUID
    
    var observationId: String? // Remote server ID
    var username: String
    var userAvatar: String?
    var observationTitle: String
    var location: String
    var lat: Double?
    var lon: Double?
    var observedAt: Date
    var likesCount: Int
    var imageName: String?
    var birdName: String?

    var displayBirdName: String {
        birdName ?? observationTitle
    }

    var displayImageName: String {
        imageName ?? "default_bird"
    }

    var observationDescription: String? {
        observationTitle
    }

    var timestamp: String? {
        ISO8601DateFormatter().string(from: observedAt)
    }

    var photoURL: String? {
        imageName
    }

    var displayUser: (name: String, observations: Int, profileImageName: String) {
        (name: username, observations: likesCount, profileImageName: userAvatar ?? "person.circle.fill")
    }
    
    init(
        id: UUID = UUID(),
        observationId: String? = nil,
        username: String,
        userAvatar: String? = nil,
        observationTitle: String,
        location: String,
        lat: Double? = nil,
        lon: Double? = nil,
        observedAt: Date = Date(),
        likesCount: Int = 0,
        imageName: String? = nil,
        birdName: String? = nil
    ) {
        self.id = id
        self.observationId = observationId
        self.username = username
        self.userAvatar = userAvatar
        self.observationTitle = observationTitle
        self.location = location
        self.lat = lat
        self.lon = lon
        self.observedAt = observedAt
        self.likesCount = likesCount
        self.imageName = imageName
        self.birdName = birdName
    }
}
