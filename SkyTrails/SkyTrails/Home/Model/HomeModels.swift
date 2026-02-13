//
//  HomeModels.swift
//  SkyTrails
//
//  Simplified - Combined UI and Data models
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - UI Models (Non-SwiftData)

// Keep these for UI compatibility
struct BirdCategory: Codable, Hashable {
    let icon: String
    let title: String
}

// Legacy support for prediction screen
struct PredictionInputData {
    var id: UUID = UUID()
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var startDate: Date? = Date()
    var endDate: Date? = Date()
    var areaValue: Int = 2
    
    var weekRange: (start: Int, end: Int)? {
        guard let start = startDate, let end = endDate else { return nil }
        
        let startWeek = start.weekOfYear
        let endWeek = end.weekOfYear
        
        if startWeek > endWeek {
            return (start: startWeek, end: endWeek + 52)
        }
        return (start: startWeek, end: endWeek)
    }
}

struct FinalPredictionResult: Hashable {
    let birdName: String
    let imageName: String
    let matchedInputIndex: Int
    let matchedLocation: (lat: Double, lon: Double)
    let spottingProbability: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(birdName)
    }
    
    static func == (lhs: FinalPredictionResult, rhs: FinalPredictionResult) -> Bool {
        return lhs.birdName == rhs.birdName
    }
}

struct NewsItem: Codable, Hashable {
    let title: String
    let summary: String
    let link: String
    let imageName: String
}

struct UpcomingBird: Codable, Hashable {
    let imageName: String
    let title: String
    let date: String
}

struct PopularSpot: Codable, Hashable {
    let id: UUID
    let imageName: String
    let title: String
    let location: String
    let latitude: Double?
    let longitude: Double?
    let speciesCount: Int
    let radius: Double?
}

// MARK: - Extensions

extension Date {
    var weekOfYear: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: self)
    }
}

// MARK: - JSON Decoding Support

struct HomeJSONData: Decodable {
    let hotspots: [HotspotData]
    let migration_sessions: [MigrationSessionData]
    let community_observations: [CommunityObservationData]
    let birdCategories: [BirdCategory]?
    let latestNews: [NewsItem]?
}

struct HotspotData: Decodable {
    let id: UUID
    let name: String
    let locality: String?
    let lat: Double
    let lon: Double
    let imageName: String?
    let speciesList: [SpeciesPresenceData]?
}

struct SpeciesPresenceData: Decodable {
    let id: UUID
    let birdId: UUID
    let validWeeks: [Int]?
    let probability: Int?
}

struct MigrationSessionData: Decodable {
    let id: UUID
    let birdId: UUID
    let startWeek: Int
    let endWeek: Int
    let hemisphere: String?
    let trajectoryPaths: [TrajectoryPathData]?
}

struct TrajectoryPathData: Decodable {
    let id: UUID
    let week: Int
    let lat: Double
    let lon: Double
    let probability: Int?
}

struct CommunityObservationData: Decodable {
    let id: UUID
    let username: String
    let userAvatar: String?
    let observationTitle: String
    let location: String
    let lat: Double?
    let lon: Double?
    let observedAt: String
    let likesCount: Int
    let imageName: String?
    let birdName: String?
}

// MARK: - Hotspot Models

@Model
final class Hotspot {
    @Attribute(.unique)
    var id: UUID
    
    var name: String
    var locality: String?
    var lat: Double
    var lon: Double
    var imageName: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \HotspotSpeciesPresence.hotspot)
    var speciesList: [HotspotSpeciesPresence]?
    
    init(id: UUID = UUID(), name: String, locality: String? = nil, lat: Double, lon: Double, imageName: String? = nil) {
        self.id = id
        self.name = name
        self.locality = locality
        self.lat = lat
        self.lon = lon
        self.imageName = imageName
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

// MARK: - Migration Models

// Result Types
struct MigrationTrajectoryResult {
    let session: MigrationSession
    let pathsAtWeek: [TrajectoryPath]
    let requestedWeek: Int
    var mostLikelyPosition: CLLocationCoordinate2D?
}

@Model
final class MigrationSession {
    @Attribute(.unique)
    var id: UUID
    
    var bird: Bird?
    var startWeek: Int
    var endWeek: Int
    var hemisphere: String? // "northern" or "southern"
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \TrajectoryPath.session)
    var trajectoryPaths: [TrajectoryPath]?
    
    @Relationship(deleteRule: .cascade, inverse: \MigrationDataPayload.session)
    var dataPayloads: [MigrationDataPayload]?
    
    init(
        id: UUID = UUID(),
        bird: Bird? = nil,
        startWeek: Int,
        endWeek: Int,
        hemisphere: String? = nil
    ) {
        self.id = id
        self.bird = bird
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.hemisphere = hemisphere
    }
}

@Model
final class TrajectoryPath {
    @Attribute(.unique)
    var id: UUID
    
    var session: MigrationSession?
    var week: Int
    var lat: Double
    var lon: Double
    var probability: Int? // 0-100
    
    init(
        id: UUID = UUID(),
        session: MigrationSession? = nil,
        week: Int,
        lat: Double,
        lon: Double,
        probability: Int? = nil
    ) {
        self.id = id
        self.session = session
        self.week = week
        self.lat = lat
        self.lon = lon
        self.probability = probability
    }
}

@Model
final class MigrationDataPayload {
    @Attribute(.unique)
    var id: UUID
    
    var session: MigrationSession?
    var weeklyData: Data? // JSON or binary data
    
    init(id: UUID = UUID(), session: MigrationSession? = nil, weeklyData: Data? = nil) {
        self.id = id
        self.session = session
        self.weeklyData = weeklyData
    }
}

// MARK: - Community Models

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
