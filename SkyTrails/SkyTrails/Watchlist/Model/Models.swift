//
//  models.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import CoreLocation

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

struct Watchlist: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var location: String
    var startDate: Date
    var endDate: Date
    
    var observedBirds: [Bird]
    var toObserveBirds: [Bird]
    
    var birds: [Bird] {
        observedBirds + toObserveBirds
    }
    
    var observedCount: Int {
        observedBirds.count
    }
    
    var stats: WatchlistStats {
        WatchlistStats(
            totalBirds: birds.count,
            observedCount: observedCount,
            rareCount: birds.filter { $0.rarity.contains(.rare) }.count
        )
    }
    
    init(id: UUID = UUID(), title: String, location: String, startDate: Date, endDate: Date, observedBirds: [Bird], toObserveBirds: [Bird]) {
        self.id = id
        self.title = title
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.observedBirds = observedBirds
        self.toObserveBirds = toObserveBirds
    }
    
    static func == (lhs: Watchlist, rhs: Watchlist) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

struct SharedWatchlist: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var location: String
    var dateRange: String
    var mainImageName: String
    var stats: SharedWatchlistStats
    var userImages: [String]
    
    var observedBirds: [Bird]
    var toObserveBirds: [Bird]
    
    var birds: [Bird] {
        observedBirds + toObserveBirds
    }
    
    init(id: UUID = UUID(), title: String, location: String, dateRange: String, mainImageName: String, stats: SharedWatchlistStats, userImages: [String], observedBirds: [Bird] = [], toObserveBirds: [Bird] = []) {
        self.id = id
        self.title = title
        self.location = location
        self.dateRange = dateRange
        self.mainImageName = mainImageName
        self.stats = stats
        self.userImages = userImages
        self.observedBirds = observedBirds
        self.toObserveBirds = toObserveBirds
    }
    
    static func == (lhs: SharedWatchlist, rhs: SharedWatchlist) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
