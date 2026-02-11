//
//  MigrationModels.swift
//  SkyTrails
//

import Foundation
import SwiftData
import CoreLocation

// MARK: - Result Types

struct MigrationTrajectoryResult {
    let session: MigrationSession
    let pathsAtWeek: [TrajectoryPath]
    let requestedWeek: Int
    var mostLikelyPosition: CLLocationCoordinate2D?
}

// MARK: - Migration Models

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
