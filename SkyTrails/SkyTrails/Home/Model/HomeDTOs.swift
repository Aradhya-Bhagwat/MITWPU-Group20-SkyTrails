//
//  HomeDTOs.swift
//  SkyTrails
//
//  Created by Gemini CLI on 16/02/2026.
//

import Foundation

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
