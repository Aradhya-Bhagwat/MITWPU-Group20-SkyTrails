//
//  Models.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import CoreLocation
import SwiftData

enum WatchlistMode: String, Codable, CaseIterable {
    case observed
    case unobserved
    case create
    
    var displayName: String {
        switch self {
        case .observed: return "Observed"
        case .unobserved: return "To Observe"
        case .create: return "Create New"
        }
    }
}

struct WatchlistStats {
    let totalBirds: Int
    let observedCount: Int
    let rareCount: Int
}

@Model
final class Watchlist {
    @Attribute(.unique) var id: UUID
    var title: String
    var location: String
    var startDate: Date
    var endDate: Date
    
    @Relationship(deleteRule: .cascade, inverse: \Bird.watchlist) var birds: [Bird]
    
    var observedBirds: [Bird] {
        birds.filter { $0.observationStatus == .observed }
    }
    
    var toObserveBirds: [Bird] {
        birds.filter { $0.observationStatus == .toObserve }
    }
    
    var observedCount: Int {
        observedBirds.count
    }
    
    var stats: WatchlistStats {
        WatchlistStats(
            totalBirds: birds.count,
            observedCount: observedCount,
            rareCount: birds.filter { $0.rarity?.contains(.rare) ?? false }.count
        )
    }
    
    init(id: UUID = UUID(), title: String, location: String, startDate: Date, endDate: Date, birds: [Bird] = []) {
        self.id = id
        self.title = title
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.birds = birds
    }
}

struct SharedWatchlistStats: Codable, Hashable {
    var greenValue: Int
    var blueValue: Int
    
    init(greenValue: Int = 0, blueValue: Int = 0) {
        self.greenValue = greenValue
        self.blueValue = blueValue
    }
}

@Model
final class SharedWatchlist {
    @Attribute(.unique) var id: UUID
    var title: String
    var location: String
    var dateRange: String
    var mainImageName: String
    var stats: SharedWatchlistStats
    var userImages: [String]
    
    @Relationship(deleteRule: .cascade, inverse: \Bird.sharedWatchlist) var birds: [Bird]
    
    var observedBirds: [Bird] {
        birds.filter { $0.observationStatus == .observed }
    }
    
    var toObserveBirds: [Bird] {
        birds.filter { $0.observationStatus == .toObserve }
    }
    
    init(id: UUID = UUID(), title: String, location: String, dateRange: String, mainImageName: String, stats: SharedWatchlistStats, userImages: [String], birds: [Bird] = []) {
        self.id = id
        self.title = title
        self.location = location
        self.dateRange = dateRange
        self.mainImageName = mainImageName
        self.stats = stats
        self.userImages = userImages
        self.birds = birds
    }
}
