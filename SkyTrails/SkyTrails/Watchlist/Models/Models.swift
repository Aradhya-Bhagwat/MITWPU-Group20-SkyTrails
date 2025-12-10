//
//  models.swift
//  SkyTrails
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import CoreLocation



enum Rarity{
	case rare
	case common
	
}


struct Bird {
	var id: UUID = UUID()
	
	let name: String
	let scientificName: String
	
	var images: [String]
	
	var rarity : [Rarity]
	
	var location: [String] // Changed from [CLLocation] to [String]
	var date : [Date]
    
    var observedBy: [String]? // List of user image names/SF symbols who observed this bird
	
    // Removed isObserved as it's now context-dependent
}


// The Watchlist model containing metadata
struct Watchlist {
	let id: UUID = UUID()
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
}

struct SharedWatchlist {
    let id: UUID = UUID()
    let title: String
    let location: String
    let dateRange: String
    let mainImageName: String
    let stats: (Int, Int)
    let userImages: [String] // Using SF Symbol names or asset names
    
    var observedBirds: [Bird] = []
    var toObserveBirds: [Bird] = []
    
    var birds: [Bird] {
        return observedBirds + toObserveBirds
    }
}
