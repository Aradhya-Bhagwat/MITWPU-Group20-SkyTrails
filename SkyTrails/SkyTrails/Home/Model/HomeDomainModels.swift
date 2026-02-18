//
//  HomeDomainModels.swift
//  SkyTrails
//
//  Created by Gemini CLI on 16/02/2026.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: - UI Models

struct BirdCategory: Codable, Hashable {
    let icon: String
    let title: String
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

// MARK: - Result Types

struct HomeScreenData {
    let upcomingBirds: [UpcomingBirdResult]
    let myWatchlistBirds: [UpcomingBirdResult]
    let recommendedBirds: [RecommendedBirdResult]
    let watchlistSpots: [PopularSpotResult]
    let recommendedSpots: [PopularSpotResult]
    let migrationCards: [DynamicMapCard]
    let recentObservations: [CommunityObservation]
    let birdCategories: [BirdCategory]
    let news: [NewsItem]
    let errorMessage: String? // Added for error propagation
    
    // MARK: - UI Computation
    
    var displayableUpcomingBirds: [UpcomingBirdUI] {
        // 1. Convert Watchlist Birds
        let watchlistUI = myWatchlistBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.statusText
            )
        }
        
        // 2. Convert Recommended Birds
        let recommendedUI = recommendedBirds.map { result in
            UpcomingBirdUI(
                imageName: result.bird.staticImageName,
                title: result.bird.commonName,
                date: result.dateRange
            )
        }
        
        // 3. Merge: Fill with watchlist birds first, then add recommended to reach 6 total
        var combinedBirds: [UpcomingBirdUI] = []
        combinedBirds.append(contentsOf: watchlistUI.prefix(6))
        
        let remainingSlots = 6 - combinedBirds.count
        if remainingSlots > 0 {
            let watchlistBirdNames = Set(watchlistUI.map { $0.title })
            let uniqueRecommended = recommendedUI.filter { !watchlistBirdNames.contains($0.title) }
            combinedBirds.append(contentsOf: uniqueRecommended.prefix(remainingSlots))
        }
        
        return combinedBirds
    }
    
    var displayableSpots: [PopularSpotUI] {
        let sourceSpots = watchlistSpots.isEmpty ? recommendedSpots : watchlistSpots
        return sourceSpots.map { spot in
            PopularSpotUI(
                id: spot.id,
                imageName: spot.imageName ?? "placeholder_image",
                title: spot.title,
                location: spot.location,
                latitude: spot.latitude,
                longitude: spot.longitude,
                speciesCount: spot.speciesCount,
                radius: spot.radius
            )
        }
    }
}

struct RecommendedBirdResult: Identifiable {
    let id = UUID()
    let bird: Bird
    let dateRange: String
}

struct PopularSpotResult: Identifiable {
    let id: UUID
    let title: String
    let location: String
    let latitude: Double
    let longitude: Double
    let speciesCount: Int
    let observedCount: Int
    let radius: Double
    let imageName: String?
    var distanceKm: Double?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct MigrationCardResult: Identifiable {
    let id = UUID()
    let bird: Bird
    let session: MigrationSession
    let currentPosition: CLLocationCoordinate2D?
    let progress: Float // 0.0 to 1.0
    let paths: [TrajectoryPath]
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var startComponents = DateComponents()
        startComponents.weekOfYear = session.startWeek
        startComponents.yearForWeekOfYear = currentYear
        startComponents.weekday = 2 // Monday
        
        var endComponents = DateComponents()
        endComponents.weekOfYear = session.endWeek
        endComponents.yearForWeekOfYear = currentYear
        endComponents.weekday = 2 // Monday
        
        if let startDate = calendar.date(from: startComponents),
           let endDate = calendar.date(from: endComponents) {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return "Week \(session.startWeek) - \(session.endWeek)"
    }
}

struct MigrationTrajectoryResult {
    let session: MigrationSession
    let pathsAtWeek: [TrajectoryPath]
    let requestedWeek: Int
    var mostLikelyPosition: CLLocationCoordinate2D?
}

// MARK: - Legacy / Prediction Support

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

enum DynamicMapCard {
    case combined(migration: MigrationPrediction, hotspot: HotspotPrediction)
}

struct MigrationPrediction {
    let birdName: String
    let birdImageName: String
    let startLocation: String
    let endLocation: String
    let currentProgress: Float
    let dateRange: String
    let pathCoordinates: [CLLocationCoordinate2D]
}

struct HotspotPrediction {
    let placeName: String
    let locationDetail: String // Added: City, State
    let weekNumber: String // Added: e.g. "Week 8"
    let speciesCount: Int
    let distanceString: String
    let dateRange: String
    let placeImageName: String
    let terrainTag: String // Added
    let seasonTag: String // Added
    let hotspots: [HotspotBirdSpot]
    let birdSpecies: [BirdSpeciesDisplay] // Added for nested list
}

struct BirdSpeciesDisplay: Hashable {
    let birdName: String
    let birdImageName: String
    let statusBadge: StatusBadge
    let sightabilityPercent: Int
    
    struct StatusBadge: Hashable {
        let title: String
        let subtitle: String
        let iconName: String
        let backgroundColorName: String // e.g., "BadgePink", "BadgeBlue"
    }
}

struct HotspotBirdSpot {
    let coordinate: CLLocationCoordinate2D
    let birdImageName: String
}

struct RelevantSighting {
    let lat: Double
    let lon: Double
    let week: Int
}

// MARK: - Extensions

extension Date {
    var weekOfYear: Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: self)
    }
}

// UI Models for Collections (Simplified View Models)
struct UpcomingBirdUI {
    let imageName: String
    let title: String
    let date: String
}

struct PopularSpotUI {
    let id: UUID
    let imageName: String
    let title: String
    let location: String
    let latitude: Double
    let longitude: Double
    let speciesCount: Int
    let radius: Double
}
