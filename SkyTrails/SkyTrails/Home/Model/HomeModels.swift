//
//  HomeModels.swift
//  SkyTrails
//
//  Simplified - UI models only
//

import Foundation
import CoreLocation

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
