//
//  models.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import CoreLocation


enum Rarity: String, Codable {
	case rare
	case common
}


struct Bird: Codable {
	var id: UUID = UUID()
	
	let name: String
	let scientificName: String
	
	var images: [String]
	
	var rarity : [Rarity]
	
	var location: [String] // Changed from [CLLocation] to [String]
	var date : [Date]
    
    var observedBy: [String]? // List of user image names/SF symbols who observed this bird
    
    var notes: String?
}


// The Watchlist model containing metadata
struct Watchlist: Codable {
	let id: UUID
	var title: String
	var location: String
	var startDate: Date
	var endDate: Date
    
    var observedBirds: [Bird]
    var toObserveBirds: [Bird]
    
    var birds: [Bird] {
        return observedBirds + toObserveBirds
    }
	
		// Helper to get counts for the UI
	var observedCount: Int {
		return observedBirds.count
	}
    
    // Custom init to provide default ID if needed, though Codable handles it if present
    init(id: UUID = UUID(), title: String, location: String, startDate: Date, endDate: Date, observedBirds: [Bird], toObserveBirds: [Bird]) {
        self.id = id
        self.title = title
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.observedBirds = observedBirds
        self.toObserveBirds = toObserveBirds
    }
}

struct SharedWatchlistStats: Codable {
    var greenValue: Int
    var blueValue: Int
}

struct SharedWatchlist: Codable {
    let id: UUID
    var title: String
    var location: String
    var dateRange: String
    var mainImageName: String
    var stats: SharedWatchlistStats
    var userImages: [String] // Using SF Symbol names or asset names
    
    var observedBirds: [Bird] = []
    var toObserveBirds: [Bird] = []
    
    var birds: [Bird] {
        return observedBirds + toObserveBirds
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
}

