//
//  CommunityModels.swift
//  SkyTrails
//

import Foundation
import SwiftData

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
