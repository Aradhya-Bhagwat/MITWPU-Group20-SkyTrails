
import Foundation
import SwiftData

@Model
final class Hotspot {
    @Attribute(.unique)
    var id: UUID
    
    var name: String
    var locality: String?
    var lat: Double
    var lon: Double
    var imageName: String?
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
    var validWeeks: [Int]?
    var weeklyProbabilities: [Int]?
    var probability: Int?
    
    init(
        id: UUID = UUID(),
        hotspot: Hotspot? = nil,
        bird: Bird? = nil,
        validWeeks: [Int]? = nil,
        weeklyProbabilities: [Int]? = nil,
        probability: Int? = nil
    ) {
        self.id = id
        self.hotspot = hotspot
        self.bird = bird
        self.validWeeks = validWeeks
        self.weeklyProbabilities = weeklyProbabilities
        self.probability = probability
    }
}

@Model
final class MigrationSession {
    @Attribute(.unique)
    var id: UUID
    
    var bird: Bird?
    var startWeek: Int
    var endWeek: Int
    @Relationship(deleteRule: .cascade, inverse: \TrajectoryPath.session)
    var trajectoryPaths: [TrajectoryPath]?
    
    @Relationship(deleteRule: .cascade, inverse: \MigrationDataPayload.session)
    var dataPayloads: [MigrationDataPayload]?
    
    init(
        id: UUID = UUID(),
        bird: Bird? = nil,
        startWeek: Int,
        endWeek: Int
    ) {
        self.id = id
        self.bird = bird
        self.startWeek = startWeek
        self.endWeek = endWeek
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
    var probability: Int?
    
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
    var weeklyData: Data?
    
    init(id: UUID = UUID(), session: MigrationSession? = nil, weeklyData: Data? = nil) {
        self.id = id
        self.session = session
        self.weeklyData = weeklyData
    }
}

@Model
final class CommunityObservation {
    @Attribute(.unique)
    var id: UUID
    
    var observationId: String?
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
