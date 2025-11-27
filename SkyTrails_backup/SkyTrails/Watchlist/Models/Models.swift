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
	let id: UUID = UUID()
	
	let name: String
	let scientificName: String
	
	var images: [String]
	
	var rarity : [Rarity]
	
	var location: [CLLocation]
	var date : [Date]
	
	
	var isObserved: Bool // Determines which tab it belongs to
}


// The Watchlist model containing metadata
struct Watchlist {
	let id: UUID = UUID()
	var title: String
	var location: String
	var startDate: Date
	var endDate: Date
	var birds: [Bird]
	
		// Helper to get counts for the UI
	var observedCount: Int {
		return birds.filter { $0.isObserved }.count
	}
}
